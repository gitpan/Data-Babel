########################################
# 030.tree ----- translate. many kinds of tree structures
#   arity      - fanout, eg, 2 for binary
#   link_type  - starlike   idtypes connect all nodes at each level
#                chainlike  each idtype connects parent to one child
#   db_type    - as usual   staggered or binary data pattern
#   skip_pairs - don't do all pairs
########################################
use t::lib;
use t::utilBabel;
use Carp;
use Test::More;
use Test::Deep;
use File::Spec;
use Text::Abbrev;
use List::Util qw(min);
use Graph::Directed;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

my($db_type,$link_type,$arity,$num_maptables,$skip_pairs)=@ARGV;
my %db_type=abbrev qw(staggered binary);
$db_type=$db_type{$db_type} || 'staggered';
my %link_type=abbrev qw(starlike chainlike);
$link_type=$link_type{$link_type} || 'starlike';
defined $arity or $arity=2;
defined $num_maptables or $num_maptables=10;
defined $skip_pairs or $skip_pairs=0;
my $last_maptable=$num_maptables-1;

# diag "\$db_type=$db_type, \$link_type=$link_type, \$arity=$arity, \$num_maptables=$num_maptables, \$skip_pairs=$skip_pairs";

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

# make graph to guide schema construction. each node will generate a maptable
my $graph=new Graph::Directed;
my $root=0;			# root is node 0
$graph->add_vertex($root);
my $more=$num_maptables-1;	# number of nodes remaining
my @roots=$root;		# queue of nodes to root subtrees

while ($more) {
  my $root=shift @roots;
  for (1..min($arity,$more)) {
    my $kid=$num_maptables-$more--;
    $graph->add_edge($root,$kid);
    push(@roots,$kid);
  }
}

# make component objects and Babel
# 
# 'link' IdTypes connect MapTables.
# 'leaf' IdTypes are private to each MapTable
#
# make explicit Masters for even-numbered leafs
#
my $sql_type='VARCHAR(255)';
my(@idtypes,@masters,@maptables);
for (0..$last_maptable) {	  # make leaf IdTypes & Masters
  my $idtype_name='leaf_'.sprintf('%03d',$_);
  push(@idtypes,new Data::Babel::IdType(name=>$idtype_name,sql_type=>$sql_type));
  push(@masters,new Data::Babel::Master(name=>$idtype_name.'_master')) unless $_%2;
}
for ($graph->vertices) {	  # make link IdTypes
  my @kids=$graph->successors($_);
  next unless @kids;
  my $idtype_name='link_'.sprintf('%03d',$_);
  if ($link_type eq 'starlike') { # 1 link per level connecting parent to all kids
    push(@idtypes,new Data::Babel::IdType(name=>$idtype_name,sql_type=>$sql_type));
  } else {			  # each link connects parent to one child
    for (@kids) {
      push(@idtypes,new Data::Babel::IdType(name=>$idtype_name.'_'.sprintf('%03d',$_),
					    sql_type=>$sql_type));
    }}}
for ($graph->vertices) {	  # make MapTables
  my $maptable_num=sprintf('%03d',$_);
  my $maptable_name="maptable_$maptable_num";
  my ($parent)=$graph->predecessors($_);
  my @kids=$graph->successors($_);
  my @idtypes;
  if ($link_type eq 'starlike') { # 1 link per level connecting parent to all kids
    push(@idtypes,'link_'.sprintf('%03d',$parent)) if defined $parent;
    push(@idtypes,"link_$maptable_num") if @kids;
  } else {			  # each link connects parent to one child
    push(@idtypes,join('_','link',sprintf('%03d',$parent),$maptable_num)) if defined $parent;
    push(@idtypes,map {join('_','link',$maptable_num,sprintf('%03d',$_))} @kids);
  }
  @idtypes=sort @idtypes;
  push(@idtypes,"leaf_$maptable_num");
  push(@maptables,new Data::Babel::MapTable(name=>$maptable_name,idtypes=>\@idtypes));
}

my $babel=new Data::Babel
  (name=>'test',idtypes=>\@idtypes,masters=>\@masters,maptables=>\@maptables);
isa_ok($babel,'Data::Babel','sanity test - $babel');
my @errstrs=$babel->check_schema;
ok(!@errstrs,'sanity test - check_schema');
diag(join("\n",@errstrs)) if @errstrs;

# print $graph,"\n";
# for my $node (sort {$a <=> $b} $graph->vertices) {
#   my @parents=$graph->predecessors($node); # should be at most !
#   my @kids=sort {$a <=> $b} $graph->successors($node);
#   print "\$node=$node: \@parents=@parents; \@kids=@kids\n";
# }
# $babel->show;
# exit(1);


# setup the database
#
for (0..$last_maptable) {
  my $data=maptable_data($_);
  my $maptable_name='maptable_'.sprintf('%03d',$_);
  load_maptable($babel,$maptable_name,$data);
}
for my $master (@{$babel->masters}) {
  my $data=($master->explicit)? master_data($master): undef;
  my $master_name=$master->name;
  load_master($babel,$master_name,$data);
}
load_ur($babel,'ur');

# run the queries. 
#
my @idtypes=sort {$a->name cmp $b->name} @{$babel->idtypes};
my @leafs=grep {$_->name=~/^leaf/} @idtypes;
my @links=grep {$_->name=~/^link/} @idtypes;
@idtypes=(@leafs,@links);

# iterate over all idtypes
for my $input_idtype (@idtypes) {
  my $ok=1;
  $ok&=doit($input_idtype,[],__FILE__,__LINE__);                                  # no outputs
  $ok&=doit($input_idtype,[@idtypes[0..$#idtypes]],__FILE__,__LINE__);            # all
  $ok&=doit($input_idtype,[@leafs[0,int($#leafs/2),$#leafs]],__FILE__,__LINE__);  # triple leafs
  $ok&=doit($input_idtype,[@links[0,int($#links/2),$#links]],__FILE__,__LINE__);  # triple links
  $ok&=doit($input_idtype,[@leafs[1,int($#leafs/2)+1],@links[0,$#links]],__FILE__,__LINE__); 
				                                                  # mixed quad
  for my $j0 (0..$#idtypes-1) {
    $ok&=doit($input_idtype,[@idtypes[$j0]],__FILE__,__LINE__);		          # single
    next if $skip_pairs;
    for my $j1 ($j0+1..$#idtypes) {
      $ok&=doit($input_idtype,[@idtypes[$j0,$j1]],__FILE__,__LINE__);	          # pair
    }}
  report_pass($ok,"input=".$input_idtype->name);
}

cleanup_ur($babel);		# clean up intermediate files
done_testing();

# args are idtypes
sub doit {
  my($input_idtype,$output_idtypes,$file,$line)=@_;
  my $input_ids=idtype2ids($input_idtype);

  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $actual=$babel->translate
    (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $label="input_idtype=".$input_idtype->name.
    ', output_idtypes='.join(' ',map {$_->name} @$output_idtypes);
  report_fail(scalar @$correct,"BAD NEWS: \$correct empty. $label",$file,$line);
  cmp_table_quietly($actual,$correct,$label,$file,$line);
#   unless (@$correct && cmp_table($actual,$correct,$label,$file,$line)) {
#     print "break here\n";
#   }
  # NG 11-01-21: added 'translate all'
    my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>$output_idtypes);
  my $actual=$babel->translate
    (input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>$output_idtypes);
  $label.=', input_ids_all';
  report_fail(scalar @$correct,"BAD NEWS: \$correct empty. $label",$file,$line);
  cmp_table_quietly($actual,$correct,$label,$file,$line);
}

# arg is maptable number
sub maptable_data {
  my($i)=@_;
  my $maptable=$babel->name2maptable('maptable_'.sprintf('%03d',$i));
  my @series=$db_type eq 'staggered'? staggered_series($i): binary_series($i);
  my @idtype_names=map {$_->name} @{$maptable->idtypes};
  # for each value in series, create a row
  my @data;
  for my $val (@series) {
    push(@data,[map {"$_/$val"} @idtype_names]);
  }
  # add in 'multi' rows: links are 'multi','multi'; leafs are 'multi_000','multi_001']
  push(@data,[map {/^leaf/? "$_/multi_000": "$_/multi"} @idtype_names]);
  push(@data,[map {/^leaf/? "$_/multi_001": "$_/multi"} @idtype_names]);
  \@data;
}
# arg can be leaf number or Master object
sub master_data {
  my $leaf=ref $_[0]? $_[0]->idtype->name: 'leaf_'.sprintf('%03d',$_[0]);
  my @series=$db_type eq 'staggered'? staggered_series(): binary_series();
  my @data=((map {"${leaf}/$_"} @series),"${leaf}/multi_000","${leaf}/multi_001");
  \@data;
}
# generate input ids for IN clause. many don't match anything.
# arg is IdType
sub idtype2ids {
  my($idtype)=@_;
  my $name=$idtype->name;
  my @series=$db_type eq 'staggered'? staggered_series(): binary_series();
  my @data=((map {"${name}/$_"} @series),"${name}/multi","${name}/multi_000","${name}/multi_001");
  \@data;
}

# generate series of raw values for use in maptables, masters, and IN clauses
sub staggered_series {
  my($i)=@_;
  defined $i?
    ((map {'a_'.sprintf('%03d',$_)} ($i..$last_maptable)),
     (map {'b_'.sprintf('%03d',$last_maptable-$_)} (0..$i))):
       (map {('a_'.sprintf('%03d',$_),'b_'.sprintf('%03d',$_))} (0..$last_maptable));
}

sub binary_series {
  my($i)=@_;
  my @series=_binary_series($num_maptables,$i);
  map {"c_$_"} @series;
}
sub _binary_series {
  my($bits,$my_bit)=@_;
  if (defined $my_bit) {	# return $bits-wide numbers with $my_bit set
    my $mask=1<<$my_bit;
    return map {sprintf '%0*b',$bits,$_} grep {$_&$mask} (0..2**$bits-1);
  } else {			# return all $bits-wide numbers
    return map {sprintf '%0*b',$bits,$_} (0..2**$bits-1);
  }
}

# for debugging. args are number of bits, and number to convert
sub as_binary_string {sprintf '%0*b',@_}
