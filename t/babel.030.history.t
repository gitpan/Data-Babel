########################################
# basic history test
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use List::MoreUtils qw(uniq);
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
cleanup_db($autodb);		# cleanup database from previous test
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

# make component objects and Babel.  type_0 has history. type_1 is implicit
my @idtypes=map {new Data::Babel::IdType(name=>"type_$_",sql_type=>'VARCHAR(255)')} (0,1);
my $master=new Data::Babel::Master(name=>'type_0_master',idtype=>$idtypes[0],history=>1);
my $maptable=new Data::Babel::MapTable(name=>"maptable",idtypes=>"type_0 type_1");
my $babel=new Data::Babel(name=>'test',idtypes=>\@idtypes,masters=>[$master],maptables=>[$maptable]);
isa_ok($babel,'Data::Babel','sanity test - $babel');

# create data & load database
my @master_data=map {["retired_$_",undef]} (1..3);
for my $m (1..3) {
  my @x_ids=map {"x$_"} (1..$m);
  for my $n (1..3) {
    for my $x_id (@x_ids) {
      push(@master_data,map {["$m-$n $x_id","a$m-$n.$_"]} (1..$n));
    }}}
load_master($babel,'type_0_master',@master_data);
my @x_type_0_ids=uniq grep {defined $_} map {$_->[0]} @master_data;
my @type_0_ids=uniq grep {defined $_} map {$_->[1]} @master_data;
my @maptable_data=map {[$_,'b']} @type_0_ids;
load_maptable($babel,'maptable',@maptable_data);
$babel->load_implicit_masters;
load_ur($babel,'ur');

# sanity tests
my $ok=1;
my $correct=39;			# empirically determined
my $actual=
  select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(_X_type_0 type_0 type_1)]);
$ok&&=is_quietly(scalar @$actual,$correct,'sanity test - ur construction');
my $correct=scalar @maptable_data;
my $actual=
  select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_0 type_1)]);
$ok&&=is_quietly(scalar @$actual,$correct,'sanity test - ur selection type_0 type_1');
my $correct=scalar @x_type_0_ids;
my $actual=
  select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(_X_type_0)]);
$ok&&=is_quietly(scalar @$actual,$correct,'sanity test - ur selection _X_type_0');
my $correct=scalar @type_0_ids;
my $actual=
  select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_0)]);
$ok&&=is_quietly(scalar @$actual,$correct,'sanity test - ur selection type_0');
my $correct=1;
my $actual=
  select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_1)]);
$ok&&=is_quietly(scalar @$actual,$correct,'sanity test - ur selection type_1');
report_pass($ok,'sanity test - ur construction and selection');

# real tests
my @ids=map {"retired_$_"} (1..3);
doit(\@ids,0,__FILE__,__LINE__);

for my $m (1..3) {
  my @x_ids=map {"x$_"} (1..$m);
  for my $n (1..3) {
    for my $x_id (@x_ids) {
      # NG 13-09-17: TODO - this should probably be
      #              my @ids=map {"$m-$_ $x_id"} (1..$n);
      #              change after tracking down Cantrell bug
      my @ids=map {"$m-$n $x_id"} (1..$n);
      # NG 13-09-17: try #2. print detailed diagnostic info to track down Cantrell FAILs
      #             failing on all but 1st time through inner loop
      #             failing in filter (2nd) test in doit; perhaps input_ids is stale...
      diag("---------- doit ----------\n");
      diag('@ids='.join(', ',@ids),"\n");
      doit(\@ids,$n,__FILE__,__LINE__);
      # NG 13-09-17: this trap caught nothing...
      # doit(\@ids,$n,__FILE__,__LINE__) or do {
      # 	# NG 13-09-15: print detailed diagnostic info to track down FAILs seen by 
      # 	#              David Cantrell (reports 34101829, 34102877)
      # 	diag_table('ur');
      # 	diag_table('maptable');
      # 	diag_table('type_0_master');
      # 	diag_table('type_1_master');
      # 	goto DONE;
      # }
    }}}
# DONE:
done_testing();

sub doit {
  my($ids,$count,$file,$line)=@_;
  my $label='ids='.join(', ',@$ids);
  # use ids for input
  my $correct=
    select_ur(babel=>$babel,
  	      input_idtype=>'type_0',input_ids=>$ids, output_idtypes=>[qw(type_0 type_1)]);
  is_quietly(scalar @$correct,$count,
  	     "BAD NEWS: select_ur got wrong number of rows!! input $label",
  	     $file,$line) or return 0;
  my $actual=$babel->translate
    (input_idtype=>'type_0',input_ids=>$ids, output_idtypes=>[qw(type_0 type_1)]);
  cmp_table($actual,$correct,"input $label",$file,$line);

  # use ids for filter
  # NG 13-09-17: try #2. print detailed diagnostic info to track down Cantrell FAILs
  #             failing on this test on all but 1st time through inner loop in main
  #             theory: input_ids (should be undef) is actually []
  our $DEBUG=1;

  my $correct=
    select_ur(babel=>$babel,
	      input_idtype=>'type_1',filters=>{type_0=>$ids},output_idtypes=>[qw(type_0 type_1)]);
  is_quietly(scalar @$correct,$count,
	     "BAD NEWS: select_ur got wrong number of rows!! filter $label",
	     $file,$line) or return 0;
  my $actual=$babel->translate
    (input_idtype=>'type_1',filters=>{type_0=>$ids},output_idtypes=>[qw(type_0 type_1)]);
  cmp_table($actual,$correct,"filter $label",$file,$line);

  our $DEBUG=0;
}
# NG 13-09-15: print table dumps to track down FAILs seen by 
#              David Cantrell (reports 34101829, 34102877)
sub diag_table {
  my($table,@cols)=@_;
  my $cols=@cols? join(',',@cols): '*';
  my $sth=$dbh->prepare(qq(SELECT $cols FROM $table)) or goto FAIL;
  $sth->execute() or goto FAIL;
  my @cols=@{$sth->{NAME}};
  my $rows=$sth->fetchall_arrayref() or goto FAIL;
  my @diag=("table $table:",join("\t",@cols));
  for my $row (@$rows) {
    # replace undef by NULL
    push(@diag,join("\t",map {defined $_? $_: 'NULL'} @$row));
  }
  push(@diag,'----------');
  my $diag=join("\n",@diag);
  diag($diag);
  return 1;
 FAIL:
  fail("dump table $table");
  diag("While trying to dump table $table for diagnostic purposes, we got the following DBI error message\n".DBI->errstr);
  return 0;
}
