########################################
# filter_hand.040.main -- test filter_id scalar
########################################
use t::lib;
use t::utilBabel;
use filter_hand;
use Test::More;
use Set::Scalar;
use Data::Babel;
use strict;

init();

for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  for my $input_idtype (@input_idtypes) {
    for my $output_idtypes (@output_idtypes) {
      my $ok=1;
      while (defined(my $filter_idtypes=$idtypes_subsets->each)) {
	$ok&&=doit_all($op,$input_idtype,$output_idtypes,[$filter_idtypes->members]) or last;
      }
      report_pass($ok,"$op input=$input_idtype, outputs=".join(',',@$output_idtypes));
    }}}
done_testing();

sub doit_all {
  my($op,$input_idtype,$output_idtypes,$filter_idtypes)=@_;
  my $ok=1;
  my $max_id=$OPTIONS{developer}? $#ids: 1;
  for my $id (0..$max_id) {
    $ok&&=doit($op,$input_idtype,$output_idtypes,$filter_idtypes,$id) or return 0;
  }
  # report_pass($ok,"$op input=$input_idtype, filters=".join(',',@$filter_idtypes). " outputs=".join(',',@$output_idtypes));
  $ok;
}
# input, outputs, filters are IdTypes
# id is array index
sub doit {
  my($op,$input_idtype,$output_idtypes,$filter_idtypes,$id)=@_;
  my $ok=1;
  my %filters;
  for my $filter_idtype (@$filter_idtypes) {
    my $filter_id="$filter_idtype/a_$ids[$id]";
    $filters{$filter_idtype}=$filter_id;
  }
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $label="$op input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, filter_ids=$id (as scalar), output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;

  # NG 10-11-08: test with limits of 0,1,2. 
  # NG 12-10-14: don't bother if result empty, since too many cases
  return $ok if empty_result($actual);
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes,
       limit=>$limit);
    my $label="$op input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, filter_ids=$id (as scalar), output_idtypes=@$output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
