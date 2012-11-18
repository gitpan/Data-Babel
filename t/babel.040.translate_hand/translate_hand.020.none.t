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

my @output_idtypes=map {[$_->members]} $idtypes_subsets->members;
for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  for my $idtype (@idtypes) {
    my $ok=1;
    # while (defined(my $idtypes_subset=$idtypes_subsets->each)) {
    for my $output_idtypes (@output_idtypes) {
      # $ok&&=doit($op,$idtype,['none'],$idtypes_subset->members);
      # $ok&&=doit($op,$idtype,[],$idtypes_subset->members);
      $ok&&=doit($op,$idtype,['none'],@$output_idtypes) or last;
      $ok&&=doit($op,$idtype,[],@$output_idtypes) or last;
      report_pass($ok,"$op input=$idtype, outputs=".join(',',@$output_idtypes));
    }
    $ok&&=doit($op,$idtype,['none'],@idtypes,@idtypes); # duplicate ouputs
    $ok&&=doit($op,$idtype,[],@idtypes,@idtypes); # duplicate ouputs
    report_pass($ok,"$op input=$idtype outputs=".join(',',@idtypes,@idtypes));  
  }
}
done_testing();

sub doit {
  my($op,$input_idtype,$input_ids,@output_idtypes)=@_;
  my $ok=1;
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>\@output_idtypes);
  my $actual=$babel->$op
      (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;
 # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>\@output_idtypes,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  # report_pass($ok,"$op input=$input_idtype, input_ids=@$input_ids, outputs=".join(',',@output_idtypes));  
  $ok;
}
