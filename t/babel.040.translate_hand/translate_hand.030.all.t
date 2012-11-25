########################################
# translate_hand.030.all -- test various ways of saying 'all input ids'
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
    doit($idtype,@output_idtypes);
  }
  doit($idtype,@idtypes,@idtypes); # duplicate ouputs
}
done_testing();

sub doit {
  my($input_idtype,@output_idtypes)=@_;
  my $ok=1;
  my $correct=select_ur
    (babel=>$babel,validate=>$OPTIONS->validate,
     input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>\@output_idtypes);

  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,output_idtypes=>\@output_idtypes,
     validate=>$OPTIONS->validate);
  my $label="input_idtype=$input_idtype, input_ids absent, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;

  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>undef,output_idtypes=>\@output_idtypes,
     validate=>$OPTIONS->validate);
  my $label="input_idtype=$input_idtype, input_ids=>undef, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;

  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>\@output_idtypes
     ,validate=>$OPTIONS->validate);
  my $label="input_idtype=$input_idtype, input_ids_all, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  my @input_ids=make_ids($input_idtype);

  my $correct=select_ur
    (babel=>$babel,validate=>$OPTIONS->validate,
     input_idtype=>$input_idtype,input_ids=>\@input_ids,output_idtypes=>\@output_idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>\@input_ids,output_idtypes=>\@output_idtypes,
     validate=>$OPTIONS->validate);
  my $label="input_idtype=$input_idtype, input_ids=>[all ids], output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  
  # test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,output_idtypes=>\@output_idtypes,,validate=>$OPTIONS->validate,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids absent, output_idtypes=@output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@output_idtypes));
}
