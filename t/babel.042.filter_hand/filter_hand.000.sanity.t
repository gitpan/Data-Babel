########################################
# filter_hand.000.sanity -- redo basic tests for sanity
########################################
use t::lib;
use t::utilBabel;
use filter_hand;
use Test::More;
use Data::Babel;
use strict;

init();

# test component-object attributes
check_handcrafted_idtypes($babel->idtypes,'mature','sanity test - Babel attribute: idtypes');
check_handcrafted_masters($babel->masters,'mature','sanity test - Babel attribute: masters');
check_handcrafted_maptables($babel->maptables,'mature',
			    'sanity test - Babel attribute: maptables');

for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  # redo basic filter test for sanity
  my $correct=prep_tabledata($data->basics_filter->data);
  my $actual=$babel->$op
    (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
     filters=>{type_004=>'type_004/a_111'},
     output_idtypes=>[qw(type_002 type_003 type_004)]);
  cmp_op($actual,$correct,$op,"sanity test - basic $op filter (scalar)",__FILE__,__LINE__);
  my $actual=$babel->$op
    (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
     filters=>{type_004=>['type_004/a_111']},
     output_idtypes=>[qw(type_002 type_003 type_004)]);
  cmp_op($actual,$correct,$op,"sanity test - basic $op filter (ARRAY)",__FILE__,__LINE__);
}

done_testing();

