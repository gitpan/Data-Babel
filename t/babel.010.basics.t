########################################
# 010.basics -- start fresh. create components & Babel. test.
# don't worry about persistence. tested separately
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
cleanup_db($autodb);		# cleanup database from previous test

my $name='test';
# expect 'old' to return undef, because database is empty
my $babel=old Data::Babel(name=>$name,autodb=>$autodb);
ok(!$babel,'old on empty database returned undef');

# create Babel directly from config files. this is is the usual case
$babel=new Data::Babel
  (name=>$name,
   idtypes=>File::Spec->catfile(scriptpath,'handcrafted.idtype.ini'),
   masters=>File::Spec->catfile(scriptpath,'handcrafted.master.ini'),
   maptables=>File::Spec->catfile(scriptpath,'handcrafted.maptable.ini'));
isa_ok($babel,'Data::Babel','Babel created from config files');

# test simple attributes
is($babel->name,$name,'Babel attribute: name');
is($babel->id,"babel:$name",'Babel attribute: id');
is($babel->autodb,$autodb,'Babel attribute: autodb');
#is($babel->log,$log,'Babel attribute: log');
# test component-object attributes
check_handcrafted_idtypes($babel->idtypes,'mature','Babel attribute: idtypes');
check_handcrafted_masters($babel->masters,'mature','Babel attribute: masters');
check_handcrafted_maptables($babel->maptables,'mature','Babel attribute: maptables');

# test internal IdType (external tested by check_handcrafted_idtypes)
my $idtype=new Data::Babel::IdType(name=>'test',display_name=>'display name',internal=>1);
{
  my $ok=1; my $label='internal IdType';
  $ok&&=report_fail($idtype->display_name eq 'display name: FOR INTERNAL USE ONLY',
		    "$label: display_name");
  $ok&&=report_fail(as_bool($idtype->external)==0,"$label: external method");
  $ok&&=report_fail(as_bool($idtype->internal)==1,"$label: internal method");
  report_pass($ok,$label);
}

# next create Babel from component objects. 
# first, extract components from existing Babel. 
#   do it this way, rather than re-reading config files, to preserve MapTable names
my($idtypes,$masters,$maptables)=$babel->get(qw(idtypes masters maptables));
@$masters=grep {$_->explicit} @$masters; # remove implicit Masters, since Babel makes them

# check component objects
check_handcrafted_idtypes($idtypes);
check_handcrafted_masters($masters);
check_handcrafted_maptables($maptables);

# create Babel using existing component objects
$babel=new Data::Babel
  (name=>$name,idtypes=>$idtypes,masters=>$masters,maptables=>$maptables);
isa_ok($babel,'Data::Babel','Babel created from component objects');

# test simple attributes
is($babel->name,$name,'Babel attribute: name');
is($babel->id,"babel:$name",'Babel attribute: id');
is($babel->autodb,$autodb,'Babel attribute: autodb');
#is($babel->log,$log,'Babel attribute: log');
# test component-object attributes
check_handcrafted_idtypes($babel->idtypes,'mature','Babel attribute: idtypes');
check_handcrafted_masters($babel->masters,'mature','Babel attribute: masters');
check_handcrafted_maptables($babel->maptables,'mature','Babel attribute: maptables');

# show: just make sure it prints something..
# redirect STDOUT to a string. adapted from perlfunc
my $showout;
open my $oldout,">&STDOUT" or fail("show: can't dup STDOUT: $!");
close STDOUT;
open STDOUT, '>',\$showout or fail("show: can't redirect STDOUT to string: $!");
$babel->show;
close STDOUT;
open STDOUT,">&",$oldout or fail("show: can't restore STDOUT: $!");
ok(length($showout)>500,'show');

# check_schema: should be true.
my @errstrs=$babel->check_schema;
ok(!@errstrs,'check_schema array context');
ok(scalar($babel->check_schema),'check_schema boolean context');

# test name2xxx & related methods
check_handcrafted_name2idtype($babel);
check_handcrafted_name2master($babel);
check_handcrafted_name2maptable($babel);
check_handcrafted_id2object($babel);
check_handcrafted_id2name($babel);

# basic translate test. much more in later tests
my $data=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.data.ini'))->autohash;
load_handcrafted_maptables($babel,$data);
# NG 12-09-27: added load_implicit_masters
$babel->load_implicit_masters;
check_implicit_masters($babel,$data,'load_implicit_masters',__FILE__,__LINE__);

load_handcrafted_masters($babel,$data);
# load_ur($babel,'ur');
my $correct=prep_tabledata($data->basics->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate');
# NG 12-08-24: added test for empty input_ids
my $correct=[];
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[],output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate empty input_ids');
# NG 11-10-21: added translate all
# NG 12-08-22: added other ways of saying 'translate all'
my $correct=prep_tabledata($data->basics_all->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate all: input_ids absent');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>undef,
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate all: input_ids=>undef');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids_all=>1,
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate all: input_ids_all=>1');
# NG 10-11-08: test limit
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)],
   limit=>1);
cmp_table($actual,$correct,'translate with limit',undef,undef,1);
# NG 12-09-22: added inputs_ids=>scalar
my $correct=prep_tabledata($data->input_scalar->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>'type_001/a_001',
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with input_ids=>scalar');

########################################
# NG 12-09-23: added count
my $correct=prep_tabledata($data->basics->data);
$correct=scalar @$correct;
my $actual=$babel->count
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
is($actual,$correct,'count: method');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)],count=>1);
is($actual,$correct,'count: option');
# empty input_ids
my $correct=0;
my $actual=$babel->count
  (input_idtype=>'type_001',input_ids=>[],output_idtypes=>[qw(type_002 type_003 type_004)]);
is($actual,$correct,'count empty input_ids: method');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[],output_idtypes=>[qw(type_002 type_003 type_004)],
  count=>1);
is($actual,$correct,'count empty input_ids: option');
# translate all
my $correct=prep_tabledata($data->basics_all->data);
$correct=scalar @$correct;
my $actual=$babel->count
  (input_idtype=>'type_001',
   output_idtypes=>[qw(type_002 type_003 type_004)]);
is($actual,$correct,'count all: method');
my $actual=$babel->translate
  (input_idtype=>'type_001',
   output_idtypes=>[qw(type_002 type_003 type_004)],count=>1);
is($actual,$correct,'count all: option');
# inputs_ids=>scalar
my $correct=prep_tabledata($data->input_scalar->data);
$correct=scalar @$correct;
my $actual=$babel->count
  (input_idtype=>'type_001',input_ids=>'type_001/a_001',
   output_idtypes=>[qw(type_002 type_003 type_004)]);
is($actual,$correct,'count input_ids=>scalar: method');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>'type_001/a_001',
   output_idtypes=>[qw(type_002 type_003 type_004)],count=>1);
is($actual,$correct,'count input_ids=>scalar: option');

########################################
# NG 12-11-23: added validate option
my $correct=prep_tabledata($data->basics_validate_option->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',
   input_ids=>[qw(type_001/invalid type_001/a_000 type_001/a_001 type_001/a_011 
		  type_001/a_110 type_001/a_111)],validate=>1,
   output_idtypes=>['type_003']);
cmp_table($actual,$correct,'translate with validate');

########################################
# NG 12-11-25: added validate method
my $correct=prep_tabledata($data->basics_validate_method->data);
my $actual=$babel->validate
  (input_idtype=>'type_001',
   input_ids=>[qw(type_001/invalid type_001/a_000 type_001/a_001 type_001/a_011 
		  type_001/a_110 type_001/a_111)]);
cmp_table($actual,$correct,'validate');

########################################
# NG 12-08-22: added filter
my $correct=prep_tabledata($data->basics_filter->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{type_004=>'type_004/a_111'},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate filter (scalar)');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{type_004=>['type_004/a_111']},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate filter (ARRAY)');

# NG 12-08-22: added ways of saying 'ignore this filter'
my $correct=prep_tabledata($data->basics->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>undef,output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with undef filters arg');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{},output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with empty filters arg');

# NG 12-09-22: added ARRAY of filters
my $correct=prep_tabledata($data->basics_filter->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>[type_004=>'type_004/a_111'],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with ARRAY of filters (1 filter)');
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>[type_001=>'type_001/a_111',type_002=>'type_002/a_111',type_003=>'type_003/a_111',
	     type_004=>'type_004/a_111',type_004=>'type_004/a_111'],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with ARRAY of filters (multiple filters)');

########################################
# NG 12-09-22: added/fixed filter=>undef and related
# test translate with filter=>undef
my $correct=prep_tabledata($data->filter_undef->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',filters=>{type_003=>undef},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with filter=>undef');

# test translate with filter=>[undef]
my $correct=prep_tabledata($data->filter_arrayundef->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',filters=>{type_003=>[undef]},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with filter=>[undef]');

# test translate with filter=>[undef,111]
my $correct=prep_tabledata($data->filter_arrayundef_111->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',filters=>{type_003=>[undef,'type_003/a_111']},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with filter=>[undef,111]');

########################################
# repeat above with ARRAY of filters
# test translate with filter=>undef
my $correct=prep_tabledata($data->filter_undef->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',filters=>[type_003=>undef],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with ARRAY of filter=>undef');

# test translate with filter=>[undef]
my $correct=prep_tabledata($data->filter_arrayundef->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',filters=>[type_003=>[undef]],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with ARRAY of filter=>[undef]');

# test translate with filter=>[undef,111]
my $correct=prep_tabledata($data->filter_arrayundef_111->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',
   filters=>[type_003=>undef,type_003=>'type_003/a_111'],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate with ARRAY of filter=>[undef,111]');

########################################
# NG 12-08-25: added using objects as idtypes
my $correct=prep_tabledata($data->basics_filter->data);
my $actual=$babel->translate
  (input_idtype=>$babel->name2idtype('type_001'),
   input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   filters=>{$babel->name2idtype('type_004')=>'type_004/a_111'},
   output_idtypes=>[map {$babel->name2idtype($_)} qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'translate using objects as idtypes');

########################################
# make schema bad in all possible ways: cyclic, disconnected, uncovered IdType
use Data::Babel::MapTable;
my $cyclic_maptable=new Data::Babel::MapTable(name=>'cyclic',idtypes=>'type_004 type_001');
my @isolated_idtypes=
  (new Data::Babel::IdType(name=>'isolated_1'),new Data::Babel::IdType(name=>'isolated_2'));
my $isolated_maptable=new Data::Babel::MapTable
  (name=>'isolated',idtypes=>'isolated_1 isolated_2');
my $uncovered_idtype=new Data::Babel::IdType(name=>'uncovered');

my $bad=new Data::Babel
  (name=>'bad',
   idtypes=>[@$idtypes,@isolated_idtypes,$uncovered_idtype],masters=>$masters,
   maptables=>[@$maptables,$cyclic_maptable,$isolated_maptable]);

my @errstrs=$bad->check_schema;
ok((@errstrs==3 && 
   grep(/not connected/,@errstrs) && 
   grep(/cyclic/,@errstrs) &&
   grep(/IdTypes not contained/,@errstrs)),
   'check_schema array context: really bad schema');
ok(!$bad->check_schema,'check_schema boolean context:  really bad schema');

done_testing();
