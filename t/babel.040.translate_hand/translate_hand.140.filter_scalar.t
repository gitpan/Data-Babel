########################################
# filter_hand.040.main -- test filter_id scalar
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Set::Scalar;
use Data::Babel;
use strict;

init();

for my $input_idtype (@idtypes) {
  for my $output_subset (@output_subsets) {
    my $ok=1;
    my @output_idtypes=$output_subset->members;
    for my $filter_subset (@filter_subsets) {
      my @filter_idtypes=$filter_subset->members;
      $ok&&=doit_all($input_idtype,\@output_idtypes,\@filter_idtypes) or last;
    }
    report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@output_idtypes));
  }}
done_testing();

sub doit_all {
  my($input_idtype,$output_idtypes,$filter_idtypes)=@_;
  my $ok=1;
  my $max_id=$OPTIONS->max_ids-1;
  for my $i (0..$max_id) {
    $ok&&=doit($input_idtype,$output_idtypes,$filter_idtypes,$i) or return 0;
  }
  # report_pass($ok,"$op input=$input_idtype, filters=".join(',',@$filter_idtypes). " outputs=".join(',',@$output_idtypes));
  $ok;
}
# input, outputs, filters are IdTypes
sub doit {
  my($input_idtype,$output_idtypes,$filter_idtypes,$i)=@_;
  my $ok=1;
  my %filters;
  for my $filter_idtype (@$filter_idtypes) {
    my($filter_id)=make_ids($filter_idtype,$i);
    $filters{$filter_idtype}=$filter_id;
  }
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $label="$OP input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, filter_id=$i (as scalar), output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;

  # NG 10-11-08: test with limits of 0,1,2. 
  # NG 12-10-14: don't bother if result empty, since too many cases
  return $ok if empty_result($actual);
  for my $limit (0,1,2) {
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes,
       limit=>$limit);
    my $label="$OP input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, filter_id=$i (as scalar), output_idtypes=@$output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
