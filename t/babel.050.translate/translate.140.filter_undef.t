########################################
# test filters that include undef
########################################
use t::lib;
use t::utilBabel;
use translate;
use Test::More;
use Data::Babel;
use strict;

init();

my $input_ids=undef;		# all input ids
for my $input (@{$babel->idtypes}) {
  for my $outputs (@output_subsets) {
    my $ok=1;
    for my $filters (@filter_subsets) {
      # make filter the usual way, then add undef to each
      my $filter=make_filter($input,undef,$filters,$outputs,'multi_ok');
      next unless %$filter;	# can't do it with empty filter
      map {push(@$_,undef)} (values %$filter);
      $ok&&=doit($input,$input_ids,$filter,$outputs,__FILE__,__LINE__);
    }
    report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs));
  }}
done_testing();
