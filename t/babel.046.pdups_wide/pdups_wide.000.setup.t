########################################
# setup database
# adapted from babel.044.pdups_hand
########################################
use t::lib;
use t::utilBabel;
use pdups_wide;
use Test::More;
use Data::Babel;
use strict;

init('setup');
my $data_ini=join('.',scripthead,'data.ini');
my $data=new Data::Babel::Config(file=>File::Spec->catfile(scriptpath,$data_ini))->autohash;

# create Babel directly from config files
# data and master files are different with history
my $idtype_ini=join('.',scripthead,'idtype.ini');
my $master_ini=join('.',scripthead,'master.ini');
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
# for my $name (map {"maptable_$_"} '001'..'007') {
for my $maptable (@{$babel->maptables}) {
  my $name=$maptable->name;
  load_maptable($babel,$maptable,$data->$name->data);
  pdups_maptable($maptable);		  # add rows that induce pseudo-dups
}
load_handcrafted_masters($babel,$data);
$babel->load_implicit_masters;
load_ur($babel,'ur');

# don't test component-object attributes.
# amply tested elsewhere and database non-standard for pseudo-duplicates tests 

# ur too big to test w/ hardcoded data. instead test a few selections
my $correct=prep_tabledata($data->ur1_select->data);
my $actual=$dbh->selectall_arrayref(qq(
SELECT DISTINCT type_001,type_002,type_003 FROM ur
WHERE type_001 NOT LIKE 'nomatch%' AND type_002 NOT LIKE 'nomatch%' 
  AND type_003 NOT LIKE 'nomatch%'));
cmp_table($actual,$correct,'ur selection 1');

my $correct=prep_tabledata($data->ur2_select->data);
my $actual=$dbh->selectall_arrayref(qq(
SELECT DISTINCT type_001,type_002,type_003 FROM ur 
WHERE type_001 LIKE 'nomatch%' AND type_002 LIKE 'nomatch%' AND type_003 LIKE 'nomatch%'));
cmp_table($actual,$correct,'ur selection 2');

my $correct=prep_tabledata($data->ur3_select->data);
my $actual=$dbh->selectall_arrayref(qq(
SELECT DISTINCT type_leaf_001,type_leaf_002,type_leaf_003 FROM ur 
WHERE type_leaf_001 NOT LIKE 'nomatch%' AND type_leaf_002 NOT LIKE 'nomatch%' 
  AND type_leaf_003 NOT LIKE 'nomatch%'));
cmp_table($actual,$correct,'ur selection 3');

my $correct=prep_tabledata($data->ur4_select->data);
my $actual=$dbh->selectall_arrayref(qq(
SELECT DISTINCT type_leaf_001,type_leaf_002,type_leaf_003 FROM ur 
WHERE type_leaf_001 LIKE 'nomatch%' AND type_leaf_002 LIKE 'nomatch%' 
  AND type_leaf_003 LIKE 'nomatch%'));
cmp_table($actual,$correct,'ur selection 4');

my $correct=prep_tabledata($data->ur5_select->data);
my $actual=$dbh->selectall_arrayref(qq(
SELECT DISTINCT type_x,type_y,type_z FROM ur 
WHERE type_x NOT LIKE '%nomatch%' AND type_y NOT LIKE '%nomatch%'));
cmp_table($actual,$correct,'ur selection 5');

my $correct=prep_tabledata($data->ur6_select->data);
my $actual=$dbh->selectall_arrayref(qq(
SELECT DISTINCT type_x,type_y,type_z FROM ur 
WHERE type_x LIKE '%nomatch%' AND type_y LIKE '%nomatch%' AND type_z LIKE '%nomatch%'));
cmp_table($actual,$correct,'ur selection 6');


# now check pseudo-duplication removal in select_ur
my $output_idtypes=\@regular_idtypes;
my $correct=prep_tabledata($data->ur1_translate->data);
my $actual=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>'type_001/a_001',filters=>{type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
cmp_table($actual,$correct,'ur selection 1 - select_ur');

my $output_idtypes=\@leaf_idtypes;
my $correct=prep_tabledata($data->ur2_translate->data);
my $actual=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>'type_001/a_001',
   filters=>{type_002=>'type_002/a_001',type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
cmp_table($actual,$correct,'ur selection 2 - select_ur');

my $output_idtypes=\@xyz_idtypes;
my $correct=prep_tabledata($data->ur3_translate->data);
my $actual=select_ur
  (babel=>$babel,
   input_idtype=>'type_leaf_001',input_ids=>'type_leaf_001/a_001',
   output_idtypes=>$output_idtypes);
cmp_table($actual,$correct,'ur selection 3 - select_ur');

done_testing();

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
