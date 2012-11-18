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

for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  for my $idtype (@idtypes) {
    while (defined(my $idtypes_subset=$idtypes_subsets->each)) {
      doit_all($idtype,$op,$idtypes_subset->members);
    }
    doit_all($idtype,$op,@idtypes,@idtypes); # duplicate ouputs
  }}
done_testing();

sub doit_all {
  my($input_idtype,$op,@output_idtypes)=@_;
  my $ok=1;
  my $max_id=$OPTIONS{developer}? $#ids: 1;
  for my $id (0..$max_id) {
    $ok&&=doit($input_idtype,$op,$id,@output_idtypes) or return 0;
  }
  report_pass($ok,"$op input=$input_idtype, outputs=".join(',',@output_idtypes));
}
# input & outputs are IdTypes
# id is array index
sub doit {
  my($input_idtype,$op,$id,@output_idtypes)=@_;
  my $ok=1;
  my $input_id="$input_idtype/a_$ids[$id]";
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>\@output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids=$input_id (as scalar), output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>\@output_idtypes,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids=$input_id (as scalar), output_idtypes=@output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
