########################################
# translate_hand.000.sanity -- redo basic tests for sanity
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
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
  # redo basic translate or count test for sanity
  my $correct=prep_tabledata($data->basics->data);
  my $actual=$babel->$op
    (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
     output_idtypes=>[qw(type_002 type_003 type_004)]);
  cmp_op($actual,$correct,$op,"sanity test - basic $op",__FILE__,__LINE__);
  # NG 11-10-21: added translate all
  my $correct=prep_tabledata($data->basics_all->data);
  my $actual=$babel->$op
    (input_idtype=>'type_001',input_ids_all=>1,
     output_idtypes=>[qw(type_002 type_003 type_004)]);
  cmp_op($actual,$correct,$op,"sanity test - basic $op all",__FILE__,__LINE__);
}

done_testing();

