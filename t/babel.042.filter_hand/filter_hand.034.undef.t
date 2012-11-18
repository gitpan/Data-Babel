########################################
# filter_hand.034.none -- test filters that include undef
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
	$ok&&=doit($op,$input_idtype,$output_idtypes,[$filter_idtypes->members],[0..$#ids]) 
	  or last;
      }
      report_pass($ok,"$op input=$input_idtype, outputs=".join(',',@$output_idtypes));
    }}}
done_testing();

# input, outputs, filters are IdTypes
sub doit {
  my($op,$input_idtype,$output_idtypes,$filter_idtypes,$ids)=@_;
  my $ok=1;
  my %filters;
  for my $filter_idtype (@$filter_idtypes) {
    my @filter_ids=(undef,map {"$filter_idtype/a_$ids[$_]"} @$ids);
    $filters{$filter_idtype}=\@filter_ids;
  }
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  my $label="$op input_idtype=$input_idtype, filter_idtypes=@$filter_idtypes, output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;
  # NG 10-11-08: test with limits of 0,1,2. 
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes,
       limit=>$limit);
    my $label="$op input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, output_idtypes=@$output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
