########################################
# filter_hand.090.big_in -- test big IN clause
########################################
use t::lib;
use t::utilBabel;
use filter_hand;
use Test::More;
use Data::Babel;
use strict;

init();

my $big=10000;
my $input_idtype='type_001';
my $filter_idtype='type_002';
my @regular_filter_ids=map {"$filter_idtype/a_$_"} @ids;
my @extra_filter_ids=map {"extra_$_"} (0..$big-1);
my $output_idtypes=['type_004'];
for my $op (qw(translate count)) {
  next unless $OPTIONS{$op};
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,filters=>{$filter_idtype=>[@regular_filter_ids]},
     output_idtypes=>$output_idtypes);
  my $actual=$babel->$op
    (input_idtype=>$input_idtype,
     filters=>{$filter_idtype=>[@regular_filter_ids,@extra_filter_ids]},
     output_idtypes=>$output_idtypes);
  my $label="$op big IN clause: size > $big";
  cmp_op($actual,$correct,$op,$label,__FILE__,__LINE__);
}
done_testing();

