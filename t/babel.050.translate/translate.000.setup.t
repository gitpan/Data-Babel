########################################
# setup databse -- setup star database. 'staggered' & 'binary' data
# many kinds of tree structures
#   arity      - fanout, eg, 2 for binary
#   link_type  - starlike   idtypes connect all nodes at each level
#                chainlike  each idtype connects parent to one child
#   db_type    - staggered or binary data pattern
#   skip_pairs - don't do all pairs
########################################
use t::lib;
use t::utilBabel;
use translate;
use Test::More;
use Text::Abbrev;
use List::Util qw(min);
use Graph::Directed;
use Hash::AutoHash qw(autohash_get);
use Class::AutoDB;
use Data::Babel;
use strict;

init('setup');
my($num_maptables,$arity,$db_type,$link_type)=
  autohash_get($OPTIONS,qw(num_maptables arity db_type link_type));
my $last_maptable=$num_maptables-1;

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
  # NG 12-11-18: move Master construction down to include links
  # push(@masters,new Data::Babel::Master(name=>$idtype_name.'_master')) unless $_%2;
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
# NG 12-11-18: make explicit Masters for even-numbered IdTypes
 @masters=map {new Data::Babel::Master(name=>$_.'_master')} grep {my($num)=$_=~/_(\d+)$/; $num%2==0} map {$_->name} @idtypes;

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

$babel=new Data::Babel
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

for (0..$last_maptable) {
  my $data=maptable_data($_);
  my $maptable_name='maptable_'.sprintf('%03d',$_);
  load_maptable($babel,$maptable_name,$data);
}
# NG 12-09-30: use load_implicit_masters
$babel->load_implicit_masters;
for my $master (@{$babel->masters}) {
  next if $master->implicit;
  my $master_name=$master->name;
  # my $data=($master->explicit)? master_data($master): undef;
  my $data=master_data($master);
  load_master($babel,$master_name,$data);
}
load_ur($babel,'ur');
my $ok=check_database_sanity($babel,'sanity test - database',$num_maptables);
report_pass($ok,'sanity test - database looks okay');

done_testing();

