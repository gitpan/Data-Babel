########################################
# main translate tests
########################################
use t::lib;
use t::utilBabel;
use pdups;
use Test::More;
use Data::Babel;
use strict;

init();

my @idtypes=@{$babel->idtypes};
my $power_set=Set::Scalar->new(@idtypes)->power_set;
# need at least 2 outputs to get pseudo-dups.
my @output_subsets=grep {2<=$_->size && $_->size<=$OPTIONS->max_outputs} $power_set->members;
 
for my $input (@idtypes){
  for my $outputs (@output_subsets) {
    my $ok=doit($input,undef,$outputs,__FILE__,__LINE__);
    report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs));
  }}
done_testing();

