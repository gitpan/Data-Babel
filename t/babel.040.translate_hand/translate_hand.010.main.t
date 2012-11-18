########################################
# translate_hand.010.main -- main tests 
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
# NG 12-08-23: rewrote to use Set::Scalar power_set and test all
#   all combinations of outputs.
# Also test with duplicate outputs
# Note that for some cases, outputs will contain input
# For each case, test 1-all input ids
#                test w/o limit and with limits of 0,1,2
for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  for my $idtype (@idtypes) {
    while (defined(my $idtypes_subset=$idtypes_subsets->each)) {
      doit_all($idtype,$op,$idtypes_subset->members);
    }
    doit_all($idtype,$op,@idtypes,@idtypes); # duplicate ouputs
  }
}
done_testing();

sub doit_all {
  my($input_idtype,$op,@output_idtypes)=@_;
  my $ok=1;
  my $max_id=$OPTIONS{developer}? $#ids: 1;
  for my $i (0..$max_id) {
    $ok&&=doit($input_idtype,$op,[0..$i],\@output_idtypes,__FILE__,__LINE__) or return 0;
  }
  report_pass($ok,"$op input=$input_idtype, outputs=".join(',',@output_idtypes));
}
# input & outputs are IdTypes
# ids are array indices
sub doit {
  my($input_idtype,$op,$ids,$output_idtypes,$file,$line)=@_;
  my $ok=1;
  my $input_ids=[map {/\D/? $_: $input_idtype.'/a_'.$ids[$_]} @$ids];
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,$file,$line) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@$output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,$file,$line,$limit) or return 0;
  }
  $ok;
}
