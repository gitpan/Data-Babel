########################################
# main filter tests
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
      # my $ok=1;
      for my $multi_ok (0,1) {
	my $filter=make_filter($input,undef,$filters,$outputs,$multi_ok);
	$ok&&=doit($input,$input_ids,$filter,$outputs,__FILE__,__LINE__);
      }
      # report_pass($ok,'input='.$input->name.' filters='.join(',',map {$_->name} @$filters).
      # 		  ' outputs='.join(' ',map {$_->name} @$outputs));
    }
    report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs));
  }}
done_testing();

