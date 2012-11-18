########################################
# filter_hand.032.off -- test filter turned off
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
      $ok&&=doit($op,$input_idtype,$output_idtypes,undef);
      $ok&&=doit($op,$input_idtype,$output_idtypes,{});
      report_pass($ok,"$op input=$input_idtype, outputs=".join(',',@$output_idtypes));
    }}}
done_testing();

# input, outputs
# filters is undef or {}
sub doit {
  my($op,$input_idtype,$output_idtypes,$filters)=@_;
  my $ok=1;
  my $filters_label=defined $filters? '{}': 'undef';
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>$filters,output_idtypes=>$output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,filters=>$filters,output_idtypes=>$output_idtypes);
  my $label="$op input_idtype=$input_idtype, filter_idtypes=$filters_label, filter_ids=undef, output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;

  # NG 10-11-08: test with limits of 0,1,2. 
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,filters=>$filters,output_idtypes=>$output_idtypes,
       limit=>$limit);
    my $label="$op input_idtype=$input_idtype, filter_idtypes=$filters_label, filter_ids=undef, output_idtypes=@$output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
