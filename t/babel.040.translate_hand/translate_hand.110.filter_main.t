########################################
# main filter tests 
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Set::Scalar;
use Data::Babel;
use strict;

init();

# NG 12-10-13: refactored to support count, validate, history
# NG 12-11-18: added history
for my $input_idtype (@idtypes) {
  for my $output_subset (@output_subsets) {
    my $ok=1;
    my @output_idtypes=$output_subset->members;
    for my $filter_subset (@filter_subsets) {
      my @filter_idtypes=$filter_subset->members;
      $ok&&=doit_all($input_idtype,\@output_idtypes,\@filter_idtypes) or last;
      # report_pass($ok,"$OP input=$input_idtype, filters=".join(',',@filter_idtypes)." outputs=".join(',',@output_idtypes));
    }
    report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@output_idtypes));
  }}
done_testing();

sub doit_all {
  my($input_idtype,$output_idtypes,$filter_idtypes)=@_;
#  my $id_prefix=($OPTIONS->history && grep {$input_idtype eq $_} qw(type_001 type_002))? "${input_idtype}/x_": "${input_idtype}/a_";
  my $ok=1;
  my $max_id=$OPTIONS->max_ids-1;
  for my $i (0..$max_id) {
    # my @input_ids=map {"${id_prefix}$_"} @ids[0..$i];
    # my @input_ids=make_ids($input_idtype,0..$i);
    $ok&&=doit($input_idtype,$output_idtypes,$filter_idtypes,$i) or return 0;
  }
  # report_pass($ok,"$OP input=$input_idtype, filters=".join(',',@$filter_idtypes). " outputs=".join(',',@$output_idtypes));
  $ok;
}
# input & outputs are IdTypes
sub doit {
  my($input_idtype,$output_idtypes,$filter_idtypes,$max_id)=@_;
  my $ok=1;
  my %filters;
  for my $filter_idtype (@$filter_idtypes) {
    my @filter_ids=make_ids($filter_idtype,0..$max_id);
    $filters{$filter_idtype}=\@filter_ids;
  }
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  # way too many cases yield empty results. skip most of them
  # return($ok) unless scalar(@$correct);
  my @input_ids=make_ids($input_idtype);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>\@input_ids,filters=>\%filters,
     output_idtypes=>$output_idtypes);
  my $label="input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, max filter_id=$max_id, output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  # do it again with input_ids absent
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids absent, filter_idtypes=@$filter_idtypes, max filter_id=$max_id, output_idtypes=@$output_idtypes";  
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  # NG 12-10-14: don't bother if result empty, since too many cases
  return $ok if empty_result($actual);
  for my $limit (0,1,2) {
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids absent, filter_idtypes=@$filter_idtypes, max filter_id=$max_id, output_idtypes=@$output_idtypes, limit=$limit";  
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
