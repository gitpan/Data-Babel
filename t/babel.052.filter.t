########################################
# 052.filter -- test filters
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use List::Util qw(min reduce);
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

# create basic MapTable data - all strings of length 2 digits over base $id_base
my $calc=new Math::BaseCalc(digits=>[0..$id_base-1]);
my @maptable_data;
for (my $i=0; $i<$id_base**2; $i++) {
  my @digits=split('',sprintf("%0.*i",2,$calc->to_base($i)));
  push(@maptable_data,\@digits);
}
# create basic Master data - all digits over base $id_base
my @master_data=(0..$id_base-1);

# create UR
my $tablename='ur';
my @column_names=map {$_->name} @idtypes;
my @column_sql_types=map {$_->sql_type} @idtypes;
my @column_defs=map {$column_names[$_].' '.$column_sql_types[$_]} (0..$#idtypes);
my @indexes=@column_names;
$dbh->do(qq(DROP TABLE IF EXISTS $tablename));
my $columns=join(', ',@column_defs);
$dbh->do(qq(CREATE TABLE $tablename ($columns)));
# create data - all strings of length $num_types digits over base $id_base
my @data;
for (my $i=0; $i<$id_base**$num_idtypes; $i++) {
  my @digits=split('',sprintf("%0.*i",$num_idtypes,$calc->to_base($i)));
  my @ids=map {"type_$_/".$digits[$_]} (0..$num_idtypes-1);
  push(@data,\@ids);
}
# load data
my @values=map {'('.join(', ',map {$dbh->quote($_)} @$_).')'} @data;
my $values=join(",\n",@values);
$dbh->do(qq(INSERT INTO $tablename VALUES\n$values));
# for sanity sake, make sure ur is correct size
my($actual)=$dbh->selectrow_array(qq(SELECT COUNT(*) FROM $tablename));
is($actual,$ur_size,"sanity test - UR has correct number of rows ($ur_size)");

# real tests begin
my $power_set=Set::Scalar->new(@idtypes)->power_set;
my @filter_subsets=grep {$_->size<=$max_filter} $power_set->members;
my @output_subsets=$OPTIONS{developer}? 
  grep {$_->size<=$max_output} $power_set->members :
  ([],[$idtypes[0]],[$idtypes[2]],[$idtypes[$#idtypes]]);

# star
doit_all('star',
	 map {new Data::Babel::MapTable(name=>"maptable_0_$_",idtypes=>"type_0 type_$_")}
	 (1..$num_idtypes-1));
# chain
doit_all('chain',
	 map {my $i=$_-1; my $j=$_; 
	      new Data::Babel::MapTable(name=>"maptable_${i}_$j",idtypes=>"type_$i type_$j")} 
	 (1..$num_idtypes-1));

#tree
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

cleanup_ur();		# clean up intermediate files
done_testing();

sub doit_all {
  my($what, @maptables)=@_;
  my $babel=new Data::Babel(name=>$what,idtypes=>\@idtypes,maptables=>\@maptables);
  # load MapTables & Masters
  for my $maptable (@{$babel->maptables}) {
    my @data;
    my @idtypes=map {$_->name} @{$maptable->idtypes};
    for my $row (@maptable_data) {
      my @digits=@$row;
      my @ids=map {$idtypes[$_].'/'.$digits[$_]} (0,1);
      push(@data,\@ids);
    }
    load_maptable($babel,$maptable,@data);
  }
  for my $master (@{$babel->masters}) {
    my @data;
    my $idtype=$master->idtype;
    for my $digit (@master_data) {
      my $id=$idtype->name."/$digit";
      push(@data,$id);
    }
    load_master($babel,$master,@data);
  }
  # do the tests!
  my $ok=1;
  for my $filter_idtypes (@filter_subsets) {
    my $filter_names=[map {$_->name} @$filter_idtypes];
    for my $output_idtypes (@output_subsets) {
      my $output_names=[map {$_->name} @$output_idtypes];
      for my $input_idtype (@idtypes) {
	my $input_name=$input_idtype->name;
	$ok&&=doit($babel,$input_name,$filter_names,$output_names,__FILE__,__LINE__);
	last unless $OPTIONS{developer};
	my $label="$what. input_idtype=$input_name, filter_idtypes=@$filter_names, output_idtypes=@$output_names";
	report_pass($ok,$label);
      }}
    my $label="$what. filter_idtypes=@$filter_names";
    report_pass($ok,$label) unless $OPTIONS{developer};
  }
}
sub doit {
  my($babel,$input_idtype,$filter_idtypes,$output_idtypes,$file,$line)=@_;
  my $ok=1;
  # phase 1. iterate w/ all filters having the same number of ids - 0, 1, 2, 3
  for my $filter_size (0..$max_filter) {
    my %filters=map {
      my $filter_idtype=$_;
      $filter_idtype=>[map {"$filter_idtype/$_"} (0..$filter_size-1)]} @$filter_idtypes;
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $correct_nrows=correct_nrows(\%filters,$input_idtype,@$output_idtypes);
    my $correct_ncols=1+scalar @$output_idtypes;
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype,filter_idtypes=@$filter_idtypes, filter_size=$filter_size, output_idtypes=@$output_idtypes";
    $ok&&=cmp_table_quietly($actual,$correct,"$label: content",$file,$line) or return 0;
    $ok&&=cmp_quietly(scalar @$actual,$correct_nrows,"$label: number of rows",$file,$line) 
      or return 0;
    next unless $correct_nrows;	# don't check columns unless there are rows
    $ok&&=cmp_quietly(scalar @{$actual->[0]},$correct_ncols,"$label: number of columns",
		      $file,$line) or return 0;
  }
  # phase 2. iterate w/ 1 filter having 1 id, others having all
  for my $filter_idtype (@$filter_idtypes) {
    my %filters=map {
      my $filter_idtype=$_;
      $filter_idtype=>[map {"$filter_idtype/$_"} (0..$id_base-1)]} @$filter_idtypes;
    $filters{$filter_idtype}="$filter_idtype/0";
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $correct_nrows=correct_nrows(\%filters,$input_idtype,@$output_idtypes);
    my $correct_ncols=1+scalar @$output_idtypes;
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype,filter_idtypes=@$filter_idtypes, filter_size=1, output_idtypes=@$output_idtypes";
    $ok&&=cmp_table_quietly($actual,$correct,"$label: content",$file,$line) or return 0;
    $ok&&=cmp_quietly(scalar @$actual,$correct_nrows,"$label: number of rows",$file,$line) 
      or return 0;
    next unless $correct_nrows;	# don't check columns unless there are rows
    $ok&&=cmp_quietly(scalar @{$actual->[0]},$correct_ncols,"$label: number of columns",
		      $file,$line) or return 0;
  }
  $ok;
}
sub correct_nrows {
  my($filters,@idtypes)=@_;
  my %filter_counts=map 
    {my $value=$filters->{$_}; 
     my $count=ref $value? scalar(@$value): defined $value? 1: 0;
     $_=>$count} keys %$filters;
  return 0 if grep {!$_} values %filter_counts; # 0 if any filter empty
  # else, all that matters are @idtypes
  my @counts=map {$filter_counts{$_} or $id_base} uniq @idtypes;
  reduce {$a*$b} @counts;
}
