########################################
# 009.util -- test the testing code - prep_tabledata, now
# maybe more someday
########################################
use t::lib;
use t::utilBabel;
use Carp;
use File::Spec;
use List::MoreUtils qw(uniq);
use List::Util qw(min max);
use Test::More;
use Test::Deep;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

my $data=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.data.ini'))->autohash;

#################### test prep_tabledata function

my $correct=[['type_001/a_001',undef],
	     [undef,'type_004/a_100'],
	     ['type_001/a_111','type_004/a_111']];
my $actual=prep_tabledata($data->prep_tabledata->data);
cmp_table($actual,$correct,'prep_tabledata - data');

check_prep_tabledata('prep_tabledata',3,2);
check_prep_tabledata('maptable_001',4,2);
check_prep_tabledata('maptable_002',4,2);
check_prep_tabledata('maptable_003',4,2);

check_prep_tabledata('type_001_master',8,1);
check_prep_tabledata('type_002_master',8,1);
check_prep_tabledata('type_001_master_history',23,2);
check_prep_tabledata('type_002_master_history',23,2);

check_prep_tabledata('type_003_master',6,1);
check_prep_tabledata('type_004_master',4,1);
check_prep_tabledata('ur',14,4);
check_prep_tabledata('ur_selection',11,2);

check_prep_tabledata('basics',2,4);
check_prep_tabledata('basics_validate_option',6,3);
check_prep_tabledata('basics_validate_method',6,3);
check_prep_tabledata('basics_all',4,4);
check_prep_tabledata('basics_filter',1,4);
check_prep_tabledata('filter_undef',2,4);
check_prep_tabledata('filter_arrayundef',2,4);
check_prep_tabledata('filter_arrayundef_111',3,4);
check_prep_tabledata('input_scalar',1,4);
check_prep_tabledata('ur_dup_outputs',12,5);
check_prep_tabledata('translate_dup_outputs',3,5);
check_prep_tabledata('translate_dup_outputs_all',8,5);

#################### test database construction

# NOTE: these tests are logically out of order, since we don't check Babel object until 010.basics
# but, we need Babel object to test select_ur, so what the heck...

# create Babel directly from config files. this is is the usual case
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
my $babel=new Data::Babel
  (name=>'test',autodb=>$autodb,
   idtypes=>File::Spec->catfile(scriptpath,'handcrafted.idtype.ini'),
   masters=>File::Spec->catfile(scriptpath,'handcrafted.master.ini'),
   maptables=>File::Spec->catfile(scriptpath,'handcrafted.maptable.ini'));
isa_ok($babel,'Data::Babel','Babel created from config files');

# construct database
load_handcrafted_maptables($babel,$data);
$babel->load_implicit_masters;
load_handcrafted_masters($babel,$data);
load_ur($babel,'ur');

# check database
my $dbh=$babel->dbh;
check_table('maptable_001',qw(type_001 type_002));
check_table('maptable_002',qw(type_002 type_003));
check_table('maptable_003',qw(type_003 type_004));

check_table('type_001_master','type_001');
check_table('type_002_master','type_002');
check_table('type_003_master','type_003');
check_table('type_004_master','type_004');
check_table('ur',qw(type_001 type_002 type_003 type_004));

#################### test select_ur function
# test cases are from 010.basics

check_select_ur
  ('basics',undef,
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_all','input_ids absent',
   input_idtype=>'type_001',output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_all','input_ids=>undef',
   input_idtype=>'type_001',input_ids=>undef,output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_all','input_ids_all=>1',
   input_idtype=>'type_001',input_ids_all=>1,output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_all','keep_pdups',
   input_idtype=>'type_001',keep_pdups=>1,output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('input_scalar',undef,
   input_idtype=>'type_001',input_ids=>'type_001/a_001',
   output_idtypes=>[qw(type_002 type_003 type_004)]);

my $big=10000;
my @input_ids=qw(type_001/a_000 type_001/a_001 type_001/a_111);
push(@input_ids,map {"extra_$_"} (1..$big));
check_select_ur
  ('basics','big IN',
   input_idtype=>'type_001',input_ids=>\@input_ids,
   output_idtypes=>[qw(type_002 type_003 type_004)]);

check_select_ur
  ('basics_validate_option',undef,
   input_idtype=>'type_001',
   input_ids=>[qw(type_001/invalid type_001/a_000 type_001/a_001 type_001/a_011 
		  type_001/a_110 type_001/a_111)],
   validate=>1,output_idtypes=>['type_003']);
check_select_ur
  ('basics_validate_method',undef,
   input_idtype=>'type_001',
   input_ids=>[qw(type_001/invalid type_001/a_000 type_001/a_001 type_001/a_011 
		  type_001/a_110 type_001/a_111)],
   validate=>1,output_idtypes=>['type_001']);

check_select_ur
  ('basics_filter','scalar',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{type_004=>'type_004/a_111'},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_filter','ARRAY',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{type_004=>['type_004/a_111']},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics','filters=>undef',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>undef,output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics','filters=>{}',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{},output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_filter','ARRAY of filters (1 filter)',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>[type_004=>'type_004/a_111'],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('basics_filter','ARRAY of filters (multiple filters)',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>[type_001=>'type_001/a_111',type_002=>'type_002/a_111',type_003=>'type_003/a_111',
	     type_004=>'type_004/a_111',type_004=>'type_004/a_111'],
   output_idtypes=>[qw(type_002 type_003 type_004)]);

check_select_ur
  ('filter_undef',undef,
   input_idtype=>'type_001',filters=>{type_003=>undef},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('filter_arrayundef',undef,
   input_idtype=>'type_001',filters=>{type_003=>[undef]},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('filter_arrayundef_111',undef,
   input_idtype=>'type_001',filters=>{type_003=>[undef,'type_003/a_111']},
   output_idtypes=>[qw(type_002 type_003 type_004)]);

check_select_ur
  ('filter_undef','ARRAY',
   input_idtype=>'type_001',filters=>[type_003=>undef],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('filter_arrayundef','ARRAY',
   input_idtype=>'type_001',filters=>[type_003=>[undef]],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
check_select_ur
  ('filter_arrayundef_111','ARRAY',
   input_idtype=>'type_001',filters=>[type_003=>[undef,'type_003/a_111']],
   output_idtypes=>[qw(type_002 type_003 type_004)]);

my @filter_ids=('type_004/a_111');
push(@filter_ids,map {"extra_$_"} (1..$big));
check_select_ur
  ('basics_filter','big IN',
   input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{type_004=>\@filter_ids},
   output_idtypes=>[qw(type_002 type_003 type_004)]);

# this one doesn't work. requires code to convert stringified ref to ref
#   conversion implemented in Babel::translate but not select_ur
# check_select_ur
#   ('basics_filter','objects as idtypes',
#    input_idtype=>$babel->name2idtype('type_001'),
#    input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>{$babel->name2idtype('type_004')=>'type_004/a_111'},
#    output_idtypes=>[map {$babel->name2idtype($_)} qw(type_002 type_003 type_004)]);

done_testing();

sub check_prep_tabledata {
  my($key,$rows,$columns)=@_;
  my($ignore,$file,$line)=caller;
  my $ok=1;
  my $actual=prep_tabledata($data->$key->data);
  $ok&&=is_quietly(scalar @$actual,$rows,"prep_tabledata $key - rows",$file,$line);
  $ok&&=is_quietly(width($actual),$columns,"prep_tabledata $key - columns",$file,$line);
  report_pass($ok,"prep_tabledata $key");
}
sub check_table {
  my($key,@columns)=@_;
  my $correct=prep_tabledata($data->$key->data);
  my $columns=join(',',@columns);
  my $sql=qq(SELECT $columns FROM $key);
  my $actual=$dbh->selectall_arrayref($sql);
  report_fail(!$dbh->err,"database query failed: ".$dbh->errstr) or return 0;
  cmp_table($actual,$correct,"table $key");
}
sub check_select_ur {
  my($key,$label,@args)=@_;
  my $correct=prep_tabledata($data->$key->data);
  my $actual=select_ur(babel=>$babel,@args);
  cmp_table($actual,$correct,"select_ur $key".(length $label? " $label":''));
}

sub width {
  my($table)=@_;
  return 0 unless @$table;
  my @widths=uniq map {scalar @$_} @$table;
  confess "Table is ragged: widths ",min(@widths),'-',max(@widths) unless scalar @widths==1;
  return $widths[0];
}
