########################################
# test filter that matches nothing
########################################
use t::lib;
use t::utilBabel;
use translate;
use Test::More;
use Data::Babel;
use strict;

init();

my $input_ids=undef;		# all input ids
my $iters=$OPTIONS->validate? 2: 1;
for(my $iter=1; $iter<=$iters; $iter++) {
  $input_ids=[undef,map {"invalid_$_"} 0..2] if $iter>1;
  for my $input (@{$babel->idtypes}) {
    for my $outputs (@output_subsets) {
      my $ok=1;
      for my $filters (@filter_subsets) {
	# make filter the usual way, then change one to match nothing
	# do it via empty list, and via value that matches nothing
	my $filter=make_filter($input,undef,$filters,$outputs,'multi_ok');
	next unless %$filter;	# can't do it with empty filter
	# my($key)=each %$filter;	# grab 1st key
	my $key=$filters->[0]->name;
	$filter->{$key}=[];
	$ok&&=doit($input,$input_ids,$filter,$outputs,__FILE__,__LINE__);
	$filter->{$key}=['none'];
	$ok&&=doit($input,$input_ids,$filter,$outputs,__FILE__,__LINE__);
	# NG 12-11-21: do it with 'none' history ids 
	if($filters->[0]->history) {
	  $filter->{$key}=["_x_${key}/none_000","_x_${key}/none_001"];
	  $ok&&=doit($input,$input_ids,$filter,$outputs,__FILE__,__LINE__);
	}
      }
      report_pass($ok,'input='.$input->name.' outputs='.join(' ',map {$_->name} @$outputs).
		  ($iter==2? ' + invalid':''));
    }}}

done_testing();

