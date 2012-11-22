########################################
# setup database
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Data::Babel;
use strict;

init('setup');

# create Babel directly from config files
# data and master files are different with history
my $idtype_ini='translate_hand.idtype.ini';
my $master_ini=!$OPTIONS->history? 'translate_hand.master.ini':
  'translate_hand.master_history.ini';
my $maptable_ini='translate_hand.maptable.ini';

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
load_handcrafted_maptables($babel,$data);
load_handcrafted_masters($babel,$data);
$babel->load_implicit_masters;
load_ur($babel,'ur');

# test component-object attributes
check_handcrafted_idtypes($babel->idtypes,'mature','sanity test - Babel attribute: idtypes');
check_handcrafted_masters($babel->masters,'mature','sanity test - Babel attribute: masters');
check_handcrafted_maptables($babel->maptables,'mature',
			    'sanity test - Babel attribute: maptables');
my $ok=check_database_sanity($babel,'sanity test - database',3);

# test ur construction for sanity
my $correct=prep_tabledata($data->ur->data);
my @columns=qw(type_001 type_002 type_003 type_004);
push(@columns,qw(_X_type_001 _X_type_002)) if $OPTIONS->history;
my $columns=join(',',@columns);
my $actual=$dbh->selectall_arrayref(qq(SELECT $columns FROM ur));
cmp_table($actual,$correct,'sanity test - ur construction');

done_testing();

