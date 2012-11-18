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

for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  for my $idtype (@idtypes) {
    while (defined(my $idtypes_subset=$idtypes_subsets->each)) {
      doit($idtype,$op,$idtypes_subset->members);
    }
    doit($idtype,$op,@idtypes,@idtypes); # duplicate ouputs
  }
}
done_testing();

sub doit {
  my($input_idtype,$op,@output_idtypes)=@_;
  my $ok=1;
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>\@output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids absent, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,input_ids=>undef,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids=>undef, output_idtypes=@output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>\@output_idtypes);
  my $label="input_idtype=$input_idtype, input_ids_all, output_idtypes=@output_idtypes";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__) or return 0;

  # test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$op
      (input_idtype=>$input_idtype,output_idtypes=>\@output_idtypes,
       limit=>$limit);
    my $label="input_idtype=$input_idtype, input_ids absent, output_idtypes=@output_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$op,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  report_pass($ok,"$op input=$input_idtype, outputs=".join(',',@output_idtypes));
}
