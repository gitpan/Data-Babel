########################################
# test all input ids
########################################
use t::lib;
use t::utilBabel;
use translate;
use Test::More;
use Data::Babel;
use strict;

init();

for my $input (@{$babel->idtypes}) {
  for my $outputs (@output_subsets) {
    my $ok=1;
    for my $input_ids (undef,'all') {
      $ok&&=doit($input,$input_ids,undef,$outputs,__FILE__,__LINE__);
    }
    report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs));
  }}
done_testing();

