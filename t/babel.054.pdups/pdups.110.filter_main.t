########################################
# main filter tests
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
# need at least 2 outputs to get pseudo-dups. but limit to 3 or more else way too many cases
my @output_subsets=grep {3<=$_->size && $_->size<=$OPTIONS->max_outputs} $power_set->members;
# filter on link types only
my $power_set=Set::Scalar->new(grep {$_->name=~/link/} @idtypes)->power_set;
my @filter_subsets=grep {$_->size<=$OPTIONS->max_filters} $power_set->members;

for my $input (@idtypes){
  for my $outputs (@output_subsets) {
    my $ok=1;
    for my $filters (@filter_subsets) {
      $ok&&=doit($input,$filters,$outputs,__FILE__,__LINE__);
    }
    report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs));
  }}
done_testing();

