########################################
# translate_hand.020.none -- test input that matches nothing
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
  my $ok=1;
  for my $output_subset (@output_subsets) {
    my @output_idtypes=$output_subset->members;
    $ok&&=doit($idtype,['none'],@output_idtypes) or last;
    $ok&&=doit($idtype,[],@output_idtypes) or last;
    report_pass($ok,"$OP input=$idtype, outputs=".join(',',@output_idtypes));
  }
  $ok&&=doit($idtype,['none'],@idtypes,@idtypes); # duplicate ouputs
  $ok&&=doit($idtype,[],@idtypes,@idtypes); # duplicate ouputs
  report_pass($ok,"$OP input=$idtype outputs=".join(',',@idtypes,@idtypes));  
}
done_testing();

sub doit {
  my($input_idtype,$input_ids,@output_idtypes)=@_;
  my $ok=1;
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>\@output_idtypes);
  my $actual=$babel->$OP
      (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  $ok;
}
