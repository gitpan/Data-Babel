########################################
# setup database
# many kinds of tree structures
#   arity      - fanout, eg, 2 for binary
#   link_type  - starlike   idtypes connect all nodes at each level
#                chainlike  each idtype connects parent to one child
#   db_type    - staggered or binary data pattern
#   skip_pairs - don't do all pairs
########################################
use t::lib;
use t::utilBabel;
use pdups;
use Test::More;
use List::Util qw(min);
use Graph::Directed;
use Hash::AutoHash qw(autohash_get);
use Class::AutoDB;
use Data::Babel;
use strict;

init('setup');
my($num_maptables,$arity,$link_type)=autohash_get($OPTIONS,qw(num_maptables arity link_type));
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
my(@idtypes,@maptables);
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

$babel=new Data::Babel(name=>'test',idtypes=>\@idtypes,maptables=>\@maptables);
isa_ok($babel,'Data::Babel','sanity test - $babel');
my @errstrs=$babel->check_schema;
ok(!@errstrs,'sanity test - check_schema');
diag(join("\n",@errstrs)) if @errstrs;

# load the database
for my $maptable (@{$babel->maptables}) {
  my $data=maptable_data($maptable);
  load_maptable($babel,$maptable,$data);  # load the main data
  pdups_maptable($maptable);		  # add rows that induce pseudo-dups
}

#all masters are implicit
$babel->load_implicit_masters;
load_ur($babel,'ur');
my $ok=check_database_sanity($babel,'sanity test - database',$num_maptables);
report_pass($ok,'sanity test - database looks okay');

done_testing();

########################################
# these functions generate data loaded into database or used in queries
# pdups test use basecalc db only
########################################
# arg is maptable number
sub maptable_data {
  my($maptable)=@_;
  my @idtype_names=map {$_->name} @{$maptable->idtypes};
  my @data;
  # all strings of length @idtype_names digits over base $basecalc
  my $calc=new Math::BaseCalc(digits=>[0..$OPTIONS->basecalc-1]);
  my $numdigits=@idtype_names;
  for (my $i=0; $i<$OPTIONS->basecalc**$numdigits; $i++) {
    my @digits=split('',sprintf("%0.*i",$numdigits,$calc->to_base($i)));
    push(@data,[map {"$idtype_names[$_]/d_$digits[$_]"} 0..$numdigits-1]);
  }
  # add in 'multi' rows: links are 'multi','multi'; leafs are 'multi_000','multi_001']
  push(@data,[map {/^leaf/? "$_/multi_000": "$_/multi"} @idtype_names]);
  push(@data,[map {/^leaf/? "$_/multi_001": "$_/multi"} @idtype_names]);
  \@data;
}
# add rows that generate pseudo-duplicates
sub pdups_maptable {
  my($maptable)=@_;
  # code adapted from utilBabel::load_maptable
  my $table=$maptable->tablename;
  my @idtypes=@{$maptable->idtypes};
  my @columns=map {$_->name} @idtypes;
  my $columns=join(',',@columns);
  for (my $i=0; $i<@columns; $i++) {
    my $column=$columns[$i];
    my @select=(('NULL')x$i,$column,('NULL')x($#columns-$i));
    my $select=join(',',@select);
    my $where="$column IS NOT NULL AND $column NOT LIKE 'nomatch%'";
    my $sql=qq(INSERT INTO $table ($columns) 
               (SELECT DISTINCT $select FROM $table WHERE $where));
    $dbh->do($sql);
    my $nomatch="'nomatch_$table'";
    my @select=(($nomatch)x$i,$column,($nomatch)x($#columns-$i));
    my $select=join(',',@select);
    my $select=join(',',@select);
    my $where="$column IS NOT NULL AND $column NOT LIKE 'nomatch%'";
    my $sql=qq(INSERT INTO $table ($columns) 
               (SELECT DISTINCT $select FROM $table WHERE $where));
    $dbh->do($sql);
  }
}

# for debugging. args are number of bits, and number to convert
sub as_binary_string {sprintf '%0*b',@_}

