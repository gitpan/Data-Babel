########################################
# regression test for duplicate output idtypes
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
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

# make component objects and Babel
my $idtypes=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.idtype.ini'))->objects('IdType');
my $masters=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.master.ini'))->objects('Master');
my $maptables=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.maptable.ini'),tt=>1)->objects('MapTable');
my $babel=new Data::Babel
  (name=>'test',idtypes=>$idtypes,masters=>$masters,maptables=>$maptables);
isa_ok($babel,'Data::Babel','sanity test - $babel');

# setup the database
my $data=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.data.ini'))->autohash;
load_handcrafted_maptables($babel,$data);
load_handcrafted_masters($babel,$data);
load_ur($babel,'ur');

# test ur construction for sanity
my $correct=prep_tabledata($data->ur->data);
my $actual=$dbh->selectall_arrayref(qq(SELECT type_001,type_002,type_003,type_004 FROM ur));
cmp_table($actual,$correct,'sanity test - ur construction');

# test ur selection (no duplicate outputs) for sanity
my $correct=prep_tabledata($data->ur_selection->data);
my $actual=select_ur(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_001 type_004)]);
cmp_table($actual,$correct,'sanity test - ur selection (no duplicate outputs)');

# redo basic translate test for sanity
my $correct=prep_tabledata($data->basics->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'sanity test - basic translate');

# test ur selection with duplicate outputs
my $correct=prep_tabledata($data->ur_dup_outputs->data);
my $actual=select_ur(babel=>$babel,urname=>'ur',
		     output_idtypes=>[qw(type_001 type_001 type_003 type_003 type_004)]);
cmp_table($actual,$correct,'ur selection with duplicate outputs');

# test translate with duplicate outputs
my $correct=prep_tabledata($data->translate_dup_outputs->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_001 type_003 type_003 type_004)]);
cmp_table($actual,$correct,'translate with duplicate outputs');

cleanup_ur($babel);		# clean up intermediate files
done_testing();
