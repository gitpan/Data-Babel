########################################
# 054.count -- test count
# based on 053.filter_undef
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use List::Util qw(min max reduce);
use List::MoreUtils qw(uniq);
use Math::BaseCalc;
use Set::Scalar;
use Getopt::Long;
use Class::AutoDB;
use Data::Babel;
use strict;

# if --developer set, run full test suite. else just a short version
our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(developer));

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
cleanup_db($autodb);		# cleanup database from previous test
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

my $num_idtypes=7;
my $id_base=4;
my $ur_size=$id_base**$num_idtypes;
my $max_filter=3;		     # max number of filters
my $max_output=1;		     # max number of outputs
my $max_filter_size=min(3,$id_base); # max number of ids per filter
my $arity=2;			     # for tree construction

# make IdTypes
my $sql_type='VARCHAR(255)';
my @idtypes=map 
  {new Data::Babel::IdType(name=>"type_$_",sql_type=>$sql_type)} (0..$num_idtypes-1);

# create uber-UR: used to make maptables
my $ubername='uber_ur';
my @column_names=map {$_->name} @idtypes;
my @column_sql_types=map {$_->sql_type} @idtypes;
my @column_defs=map {$column_names[$_].' '.$column_sql_types[$_]} (0..$#idtypes);
my @indexes=@column_names;
$dbh->do(qq(DROP TABLE IF EXISTS $ubername));
my $columns=join(', ',@column_defs);
$dbh->do(qq(CREATE TABLE $ubername ($columns)));
# create data - all strings of length $num_types digits over base $id_base
my $calc=new Math::BaseCalc(digits=>[0..$id_base-1]);
my @data;
for (my $i=0; $i<$id_base**$num_idtypes; $i++) {
  my @digits=split('',sprintf("%0.*i",$num_idtypes,$calc->to_base($i)));
  my @ids=map {"type_$_/".$digits[$_]} (0..$num_idtypes-1);
  push(@data,\@ids);
}
# load data
my @values=map {'('.join(', ',map {$_=~/0$/? 'NULL': $dbh->quote($_)} @$_).')'} @data;
my $values=join(",\n",@values);
$dbh->do(qq(INSERT INTO $ubername VALUES\n$values));
# for sanity sake, make sure ur is correct size
my($actual)=$dbh->selectrow_array(qq(SELECT COUNT(*) FROM $ubername));
is($actual,$ur_size,"sanity test - uber UR has correct number of rows ($ur_size)");

# real tests begin
my $power_set=Set::Scalar->new(@idtypes)->power_set;
my @filter_subsets=grep {$_->size<=$max_filter} $power_set->members;
my @output_subsets=$OPTIONS{developer}? 
  grep {$_->size<=$max_output} $power_set->members :
  ([],[$idtypes[0]],[$idtypes[2]],[$idtypes[$#idtypes]]);

# star
cleanup_db($autodb);		# cleanup database from previous test
doit_all('star',
	 map {new Data::Babel::MapTable(name=>"maptable_0_$_",idtypes=>"type_0 type_$_")}
	 (1..$num_idtypes-1));
# chain
cleanup_db($autodb);		# cleanup database from previous test
doit_all('chain',
	 map {my $i=$_-1; my $j=$_; 
	      new Data::Babel::MapTable(name=>"maptable_${i}_$j",idtypes=>"type_$i type_$j")} 
	 (1..$num_idtypes-1));

#tree
cleanup_db($autodb);		# cleanup database from previous test
my @maptables;
my @roots=(0);
my $more=$num_idtypes-1;
while ($more) {
  my $root=shift @roots;
  for (1..min($arity,$more)) {
    my $kid=$num_idtypes-$more--;
    push
      (@maptables,
       new Data::Babel::MapTable(name=>"maptable_${root}_$kid",idtypes=>"type_$root type_$kid"));
    push(@roots,$kid);
  }
}
doit_all('tree',@maptables);

done_testing();

sub doit_all {
  my($what, @maptables)=@_;
  my $babel=new Data::Babel(name=>$what,idtypes=>\@idtypes,maptables=>\@maptables);
  my $dbh=$babel->autodb->dbh;
  my $ubername='uber_ur';
  # load maptables, masters, ur - have to do maptables first
  for my $maptable (@{$babel->maptables}) {
    # code adpated from utilBabel::load_maptable
    my $tablename=$maptable->tablename;
    $dbh->do(qq(DROP TABLE IF EXISTS $tablename));
    my @idtypes=@{$maptable->idtypes};
    my @column_names=map {$_->name} @idtypes;
    my $column_sql=join(', ',@column_names);
    my $where_sql=qq($column_names[0] IS NOT NULL OR $column_names[1] IS NOT NULL);
    my $sql=qq(CREATE TABLE $tablename AS SELECT DISTINCT $column_sql FROM $ubername WHERE $where_sql);
    $dbh->do($sql);
  }
  # NG 12-09-30: all masters are implicit. wrong headed to load master data
  #              use load_implicit masters instead
  $babel->load_implicit_masters;
 # make real ur
  load_ur($babel);
  # # load masters
  # for my $master (@{$babel->masters}) {
  #   # code adpated from utilBabel::load_master
  #   my $tablename=$master->tablename;
  #   $dbh->do(qq(DROP TABLE IF EXISTS $tablename));
  #   my $idtype=$master->idtype;
  #   my $column_name=$idtype->name;
  #   my $where_sql=qq($column_name IS NOT NULL);
  #   my $sql=qq(CREATE TABLE $tablename AS SELECT DISTINCT $column_name FROM ur WHERE $where_sql);
  #   $dbh->do($sql);
  # }

  # do the tests!
  my $ok=1;
  for my $filter_idtypes (@filter_subsets) {
    my $filter_names=[map {$_->name} @$filter_idtypes];
    for my $output_idtypes (@output_subsets) {
      my $output_names=[map {$_->name} @$output_idtypes];
      for my $input_idtype (@idtypes) {
	my $input_name=$input_idtype->name;
	$ok&&=doit($babel,$what,$input_name,$filter_names,$output_names,__FILE__,__LINE__);
	last unless $OPTIONS{developer};
	my $label="$what. input_idtype=$input_name, filter_idtypes=@$filter_names, output_idtypes=@$output_names";
	report_pass($ok,$label);
      }}
    my $label="$what. filter_idtypes=@$filter_names";
    report_pass($ok,$label) unless $OPTIONS{developer};
  }
}
sub doit {
  my($babel,$what,$input_idtype,$filter_idtypes,$output_idtypes,$file,$line)=@_;
  my $ok=1;
  # phase 1. iterate w/ all filters having undef + same number of ids - 1, 2, 3
  for my $filter_size (1..$max_filter) {
    my %filters=map {
      my $filter_idtype=$_;
      $filter_idtype=>[undef,map {"$filter_idtype/$_"} (1..$filter_size-1)]} @$filter_idtypes;
    my $correct=count_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $actual=$babel->count
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="$what phase 1: input_idtype=$input_idtype,filter_idtypes=@$filter_idtypes, filter_size=$filter_size, output_idtypes=@$output_idtypes";
    $ok&&=cmp_quietly($actual,$correct,"$label",$file,$line) or return 0;
  }
  # phase 2. iterate w/ 1 filter having 1 id, others undef
  for my $filter_idtype (@$filter_idtypes) {
    my %filters=map {
      my $filter_idtype=$_;
      $filter_idtype=>[map {"$filter_idtype/$_"} (1..$id_base-1)]} @$filter_idtypes;
    $filters{$filter_idtype}=undef;
    my $correct=count_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $actual=$babel->count
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="$what phase 2: input_idtype=$input_idtype,filter_idtypes=@$filter_idtypes, filter_size=1, output_idtypes=@$output_idtypes";
    $ok&&=cmp_quietly($actual,$correct,"$label",$file,$line) or return 0;
  }
  $ok;
}

