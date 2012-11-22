########################################
# translate_hand.040.main -- test input_id scalar
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Set::Scalar;
use Data::Babel;
use strict;

init();

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
  # my $id_prefix=($OPTIONS->history && grep {$input_idtype eq $_} qw(type_001 type_002))? "${input_idtype}/x_": "${input_idtype}/a_";
  my $ok=1;
  my $max_id=$OPTIONS->max_ids-1;
  for my $i (0..$max_id) {
    # my $input_id="${id_prefix}$ids[$i]";
    my($input_id)=make_ids($input_idtype,$i);
    $ok&&=doit($input_idtype,$input_id,@output_idtypes) or return 0;
  }
  report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@output_idtypes));
}
# input & outputs are IdTypes
sub doit {
  my($input_idtype,$input_id,@output_idtypes)=@_;
  my $ok=1;
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>\@output_idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids=$input_id (as scalar), output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>\@output_idtypes,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids=$input_id (as scalar), output_idtypes=@output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
