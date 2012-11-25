########################################
# main translate tests
########################################
use t::lib;
use t::utilBabel;
use translate;
use Test::More;
use Data::Babel;
use strict;

init();

for my $input (@{$babel->idtypes}) {
  my $input_ids=idtype2ids($input);
  push(@$input_ids,map {"invalid_$_"} 0..2) if $OPTIONS->validate;
  for my $outputs (@output_subsets) {
    my $ok=doit($input,$input_ids,undef,$outputs,__FILE__,__LINE__);
    report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs));
  }}
done_testing();

