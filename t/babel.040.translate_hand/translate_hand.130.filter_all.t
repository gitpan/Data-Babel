########################################
# test various ways of saying 'all filter ids'
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Set::Scalar;
use Data::Babel;
use strict;

init();

for my $input_idtype (@idtypes) {
  for my $output_subset (@output_subsets) {
    my $ok=1;
    my @output_idtypes=$output_subset->members;
    for my $filter_subset (@filter_subsets) {
      my @filter_idtypes=$filter_subset->members;
      $ok&&=doit($input_idtype,\@output_idtypes,\@filter_idtypes) or last;
    }
    report_pass($ok,"$OP input=$input_idtype, outputs=".join(',',@output_idtypes));
  }}
done_testing();

# input, outputs, filters are IdTypes
sub doit {
  my($input_idtype,$output_idtypes,$filter_idtypes)=@_;
  my $ok=1;
  my %filters=map {$_=>undef} @$filter_idtypes;
  my @args=(input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
  push(@args,validate=>1) if $OPTIONS->validate;
  my $correct=select_ur(babel=>$babel,@args);
  my $actual=$babel->$OP(@args);
  my $label="$OP input_idtype=$input_idtype, filter_idtypes=@$filter_idtypes, filter_ids=undef, output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  # do it with all filter ids
  my %filters=map {$_=>[make_ids($_)]} @$filter_idtypes;
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes,
     validate=>$OPTIONS->validate);
  my $label="$OP input_idtype=$input_idtype, filter_idtypes=@$filter_idtypes, filter_ids=[all ids], output_idtypes=@$output_idtypes";
  $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;

  # NG 10-11-08: test with limits of 0,1,2. 
  my %filters=map {$_=>undef} @$filter_idtypes;
  for my $limit (0,1,2) {
      my $actual=$babel->$OP(@args,limit=>$limit);
      my $label="$OP input_idtype=$input_idtype, filter_idtypes=@$filter_idtypes, filter_ids=undef, output_idtypes=@$output_idtypes, limit=$limit";
      $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__,$limit) or return 0;
    }
 # if validate set, do with invalid input ids
  if ($OPTIONS->validate) {
    my @input_ids=(make_ids($input_idtype),make_invalid_ids($input_idtype,1));
    my $correct=select_ur
      (babel=>$babel,validate=>1,
       input_idtype=>$input_idtype,input_ids=>\@input_ids,filters=>\%filters,
       output_idtypes=>$output_idtypes);
    my $actual=$babel->$OP
      (input_idtype=>$input_idtype,input_ids=>\@input_ids,filters=>\%filters,
       output_idtypes=>$output_idtypes,validate=>1);
    my $label="input_idtype=$input_idtype, all input_ids + invalid, filter_idtypes=@$filter_idtypes, filter_ids=undef, output_idtypes=@$output_idtypes";
    $ok&&=cmp_op_quietly($actual,$correct,$OP,$label,__FILE__,__LINE__) or return 0;
  }
  $ok;
}
