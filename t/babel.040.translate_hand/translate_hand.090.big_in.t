########################################
# translate_hand.090.big_in -- test big IN clause
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Data::Babel;
use strict;

init();

my $big=10000;
for my $idtype (@idtypes) {
  my $ok=doit($idtype);
  report_pass($ok,"$OP input=$idtype");
}
done_testing();

sub doit {
  my($input_idtype)=@_;
  my @regular_input_ids=make_ids($input_idtype);
  my @extra_input_ids=(@regular_input_ids,map {"extra_$_"} (0..$big-1));
  my $ok=1;
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>\@regular_input_ids,output_idtypes=>\@idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>[@regular_input_ids,@extra_input_ids],
     output_idtypes=>\@idtypes);
  my $label="input_idtype=$input_idtype";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,input_ids=>[@regular_input_ids,@extra_input_ids],
       output_idtypes=>\@idtypes,limit=>$limit);
    my $label="input_idtype=$input_idtype, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}
