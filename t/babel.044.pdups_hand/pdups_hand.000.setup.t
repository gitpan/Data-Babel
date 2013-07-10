########################################
# setup database
# adapted from babel.040.translate_hand
########################################
use t::lib;
use t::utilBabel;
use pdups_hand;
use Test::More;
use Data::Babel;
use strict;

init('setup');
my $data_ini=join('.',scripthead,'data'.($OPTIONS{history}? '_history.ini': '.ini'));
my $data=new Data::Babel::Config(file=>File::Spec->catfile(scriptpath,$data_ini))->autohash;

# create Babel directly from config files
# data and master files are different with history
my $idtype_ini=join('.',scripthead,'idtype.ini');
my $master_ini=join('.',scripthead,'master'.($OPTIONS{history}? '_history.ini': '.ini'));
my $maptable_ini=join('.',scripthead,'maptable.ini');

my $name='test';
$babel=new Data::Babel
  (name=>$name,
   idtypes=>File::Spec->catfile(scriptpath,$idtype_ini),
   masters=>File::Spec->catfile(scriptpath,$master_ini),
   maptables=>File::Spec->catfile(scriptpath,$maptable_ini));
isa_ok($babel,'Data::Babel','sanity test - Babel created from config files');

# quietly test simple attributes
cmp_quietly($babel->name,$name,'sanity test - Babel attribute: name');
cmp_quietly($babel->id,"babel:$name",'sanity test - Babel attribute: id');
cmp_quietly($babel->autodb,$autodb,'sanity test - Babel attribute: autodb');

# setup the database
for my $name (qw(maptable_001 maptable_002 maptable_003 maptable_004 maptable_005)) {
  load_maptable($babel,$name,$data->$name->data);
}
load_handcrafted_masters($babel,$data);
$babel->load_implicit_masters;
load_ur($babel,'ur');

# don't test component-object attributes.
# amply tested elsewhere and database non-standard for pseudo-duplicates tests 

# ur too big to test w/ hardcoded data. instead test a few selections
my @columns=@regular_idtypes;
push(@columns,@history_columns) if $OPTIONS->history;
my $columns=join(',',@columns);
my $correct=prep_tabledata($data->ur1_select->data);
my $actual=$dbh->selectall_arrayref(qq(
  SELECT DISTINCT $columns FROM ur 
  WHERE type_001 like '%a_001' and type_003 like '%a_100'));
cmp_table($actual,$correct,'ur selection 1');

my $correct=prep_tabledata($data->ur2_select->data);
my $actual=$dbh->selectall_arrayref(qq(
  SELECT DISTINCT $columns FROM ur 
  WHERE type_001 like '%a_111' and type_003 like '%a_111'));
cmp_table($actual,$correct,'ur selection 2');

# now check pseudo-duplication removal in select_ur
my $output_idtypes=\@regular_idtypes;
my $correct=prep_tabledata($data->ur1_translate->data);
my $input_id=!$OPTIONS->history? 'type_001/a_001': 'type_001/x_001';
my $actual=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>$input_id,filters=>{type_003=>'type_003/a_100'},
   output_idtypes=>$output_idtypes);
cmp_table($actual,$correct,'ur selection 1 - select_ur');

my $correct=prep_tabledata($data->ur2_translate->data);
my $input_id=!$OPTIONS->history? 'type_001/a_111': 'type_001/x_111';
my $actual=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>$input_id,filters=>{type_003=>'type_003/a_111'},
   output_idtypes=>$output_idtypes);
cmp_table($actual,$correct,'ur selection 2 - select_ur');

done_testing();

