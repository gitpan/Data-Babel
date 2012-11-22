########################################
# test big IN clause
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Data::Babel;
use strict;

init();

my $big=10000;
for my $input_idtype (@idtypes) {
  my @filter_idtypes=@idtypes;
  my $ok=doit($input_idtype,\@filter_idtypes);
  report_pass($ok,"$OP input=$input_idtype");
}
done_testing();

sub doit {
  my($input_idtype,$filter_idtypes)=@_;
   my $ok=1;
  my(%regular_filters,%filters);
  for my $filter_idtype (@$filter_idtypes) {
    my @regular_filter_ids=make_ids($filter_idtype);
    my @extra_filter_ids=(@regular_filter_ids,map {"extra_$_"} (0..$big-1));
    $regular_filters{$filter_idtype}=\@regular_filter_ids;
    $filters{$filter_idtype}=[@regular_filter_ids,@extra_filter_ids];
  }
 my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>\%regular_filters,output_idtypes=>\@idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>\@idtypes);
  my $label="input_idtype=$input_idtype, filter_idtypes=@$filter_idtypes";
  $ok&&is_quietly(scalar(@$correct),1,"BAD NEWS: select_ur got wrong number of rows!! $label") 
    or return 0;
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label) or return 0;
  # NG 10-11-08: test with limits of 0,1,2
  for my $limit (0,1,2) {
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>\@idtypes,limit=>$limit);
    my $label="input_idtype=$input_idtype, filter_idtypes=@$filter_idtypes, limit=$limit";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
  }
  $ok;
}

