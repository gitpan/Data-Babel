########################################
# translate_hand.010.main -- main tests 
# adapted from babel.040.translate_hand
########################################
use t::lib;
use t::utilBabel;
use pdups_wide;
use List::Util qw(min);
use Set::Scalar;
use Test::More;
use Data::Babel;
use strict;

init();

# need at least 2 outputs to get pseudo-dups. 
# all combinations of types work
# NG 13-07-09: use power_subsets. much faster than Set::Scalar for large sets 
#              if number of subsets not too big
# my $power_set=Set::Scalar->new(@idtypes)->power_set;
# my @output_subsets=sort_name_lists(map {[$_->members]} grep {$_->size>=2} $power_set->members);
my @output_subsets=power_subsets(\@idtypes,2,4);
for my $output_idtypes (@output_subsets) {
  for my $input_idtype (@regular_idtypes) {
    doit_all($input_idtype,$output_idtypes);
  }
}

done_testing();

# do it with one id ('001') and all ids
sub doit_all {
  my($input_idtype,$output_idtypes)=@_;
  my $ok=1;
  my @input_ids="$input_idtype/a_001";
  push(@input_ids,map {"$input_idtype/$_"} qw(valid invalid)) if $OPTIONS->validate;
  $ok&&=doit($input_idtype,\@input_ids,$output_idtypes,__FILE__,__LINE__) or return 0;
  $ok&&=doit($input_idtype,undef,$output_idtypes,__FILE__,__LINE__) or return 0;
  report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@$output_idtypes));
}
sub doit {
  my($input_idtype,$input_ids,$output_idtypes,$file,$line)=@_;
  my $ok=1;
  my @args=(input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  push(@args,validate=>1) if $OPTIONS->validate;
  my $correct=select_ur(babel=>$babel,@args);
  my $actual=$babel->$OP(@args);
  my $label="input_idtype=$input_idtype, input_ids=".
    ($input_ids? "@$input_ids": 'ALL')." output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,$file,$line) or return 0;
  $ok;
}
