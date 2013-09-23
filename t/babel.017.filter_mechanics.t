########################################
# 017.filter_mechanics -- test all forms of translate filter arg
# some parts adapted from 010.basics
# STUB!!
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use Data::Babel;
use strict;

our($autodb,$babel,$dbh,$history,@ids,@qids,@ops);
our $num_idtypes=4;
our $num_ids=3;
# my $data;

for $history (qw(none all even odd)) {
  init($history);
  pass("stub - history=$history");
}
done_testing();

# # various ways of saying 'ignore this filter'
# my $correct=prep_tabledata($data->basics->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>undef,output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'filters=>undef');
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>{},output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'filters=>empty HASH');
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>[],output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'filters=>ARRAY');

# # TODO: string, stringref, object

# # HASH: filters(s)=>[]

# # HASH: filter(s)=>undef

# # HASH: filter(s)=>id

# # HASH: filter(s)=>SQL

# # HASH: filter(s)=>object

# # HASH: filters(s)=>all 

# # repeat with ARRAY. remember to include 'naked' objects without (not idtype=>object) 

# # include idtypes as objects - have code to convert stringified objects back to objects

# my $correct=prep_tabledata($data->basics_filter->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>{type_004=>'type_004/a_111'},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'filters HASH: filter=>scalar');
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>{type_004=>['type_004/a_111']},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'filters HASH: filter=>ARRAY of 1');

# # NG 12-09-22: added ARRAY of filters
# my $correct=prep_tabledata($data->basics_filter->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>[type_004=>'type_004/a_111'],
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with ARRAY of filters (1 filter)');
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>[type_001=>'type_001/a_111',type_002=>'type_002/a_111',type_003=>'type_003/a_111',
# 	     type_004=>'type_004/a_111',type_004=>'type_004/a_111'],
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with ARRAY of filters (multiple filters)');

# # NG 13-07-16: filter=>'invalid',filter=>[] - match nothing
# my $correct=[];
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>[type_004=>'invalid'],
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with filter matching nothing (scalar)');
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>{type_004=>['invalid']},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with filter matching nothing (ARRAY)');
# my $actual=$babel->translate
#   (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
#    filters=>{type_004=>[]},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with filter matching nothing (empty ARRAY)');

# ########################################
# # NG 12-09-22: added/fixed filter=>undef and related
# # test translate with filter=>undef
# my $correct=prep_tabledata($data->filter_undef->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',filters=>{type_003=>undef},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with filter=>undef');

# # test translate with filter=>[undef]
# my $correct=prep_tabledata($data->filter_arrayundef->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',filters=>{type_003=>[undef]},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with filter=>[undef]');

# # test translate with filter=>[undef,111]
# my $correct=prep_tabledata($data->filter_arrayundef_111->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',filters=>{type_003=>[undef,'type_003/a_111']},
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with filter=>[undef,111]');

# ########################################
# # repeat above with ARRAY of filters
# # test translate with filter=>undef
# my $correct=prep_tabledata($data->filter_undef->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',filters=>[type_003=>undef],
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with ARRAY of filter=>undef');

# # test translate with filter=>[undef]
# my $correct=prep_tabledata($data->filter_arrayundef->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',filters=>[type_003=>[undef]],
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with ARRAY of filter=>[undef]');

# # test translate with filter=>[undef,111]
# my $correct=prep_tabledata($data->filter_arrayundef_111->data);
# my $actual=$babel->translate
#   (input_idtype=>'type_001',
#    filters=>[type_003=>undef,type_003=>'type_003/a_111'],
#    output_idtypes=>[qw(type_002 type_003 type_004)]);
# cmp_table($actual,$correct,'translate with ARRAY of filter=>[undef,111]');

# done_testing();

# from babel.016.filter_object/filter_object.pm & filter_object.040.sql.t
sub init {
  $history=shift;		# $history is global
  $history='none' unless defined $history;
  $autodb=new Class::AutoDB(database=>'test',create=>1); 
  # isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
  # TODO: do we need $dbh?? if not also remove from 'our'
  $dbh=$autodb->dbh;
  cleanup_db($autodb);	# cleanup database from previous test
  # make component objects and Babel.
  my @idtypes=
    map {new Data::Babel::IdType(name=>"type_$_",sql_type=>'VARCHAR(255)')} (0..($num_idtypes-1));
  my @masters=map {
    new Data::Babel::Master
      (name=>"type_${_}_master",idtype=>$idtypes[$_],
       explicit=>has_history($_),history=>has_history($_))} (0..$#idtypes);
  my @maptables=map {
    new Data::Babel::MapTable(name=>"maptable_$_",idtypes=>[@idtypes[$_,$_+1]])} (0..($#idtypes-1));
  $babel=new Data::Babel
    (name=>'test',autodb=>$autodb,idtypes=>\@idtypes,masters=>\@masters,maptables=>\@maptables);
  # isa_ok($babel,'Data::Babel','sanity test - $babel');
  # setup the database. all maptables have same data. masters, too, except for undefs
  my @data=map {(["a_$_","a_$_"],[undef,"a_$_"],["a_$_",undef])} (0..($num_ids-1));
  map {load_maptable($babel,$_,@data)} @maptables;
  my @data=map {["a_$_","a_$_"]} (0..($num_ids-1));
  map {load_master($babel,$_,@data)} grep {$_->history} @masters;
  $babel->load_implicit_masters;
  load_ur($babel,'ur');
}
sub has_history {
  my $i=shift;
  ($history eq 'none' || ($history eq 'odd' && !($i%2)) || ($history eq 'even' && $i%2))? 0: 1;
}
# TODO: do we need colname??
# generate column name for type taking into account histories
sub colname {
  my($i)=$_[0]=~/(\d+)/;
  has_history($i)? "_X_type_$i": "type_$i";
}
