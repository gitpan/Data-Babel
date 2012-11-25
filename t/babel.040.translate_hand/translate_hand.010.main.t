########################################
# translate_hand.010.main -- main tests 
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use List::Util qw(min);
use Set::Scalar;
use Test::More;
use Data::Babel;
use strict;

init();

# NG 12-10-13: refactored to support count, validate, history
# NG 12-08-23: rewrote to use Set::Scalar power_set and test all
#   all combinations of outputs.
# Also test with duplicate outputs
# Note that for some cases, outputs will contain input
# For each case, test 1-all input ids
#                test w/o limit and with limits of 0,1,2
# NG 12-11-18: added history
for my $idtype (@idtypes) {
  for my $output_subset (@output_subsets) {
    my @output_idtypes=$output_subset->members;
    doit_all($idtype,@output_idtypes);
  }
  doit_all($idtype,@idtypes,@idtypes); # duplicate ouputs
}
done_testing();

sub doit_all {
  my($input_idtype,@output_idtypes)=@_;
  my $ok=1;
  my $max_id=$OPTIONS->max_ids-1;
  for my $i (0..$max_id) {
    my @input_ids=make_ids($input_idtype,0..$i);
    push(@input_ids,make_invalid_ids($input_idtype,$i+1)) if $OPTIONS->validate;
    $ok&&=doit($input_idtype,\@input_ids,\@output_idtypes,__FILE__,__LINE__) or return 0;
  }
  report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@output_idtypes));
}
sub doit {
  my($input_idtype,$input_ids,$output_idtypes,$file,$line)=@_;
  my $ok=1;
  my @args=(input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  push(@args,validate=>1) if $OPTIONS->validate;
  my $correct=select_ur(babel=>$babel,@args);
  my $actual=$babel->$OP(@args);
  my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,$file,$line) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$OP(@args,limit=>$limit);  
 my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@$output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,$file,$line,$limit) or return 0;
  }
  $ok;
}
