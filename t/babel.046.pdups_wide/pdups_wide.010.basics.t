########################################
# test all methods in basic fashion
# adapted from babel.044.pdups_hand
########################################
use t::lib;
use t::utilBabel;
use pdups_wide;
use Test::More;
use Data::Babel;
use strict;

init();
my $output_idtypes=\@regular_idtypes;;

#  translate, count
my $output_idtypes=\@regular_idtypes;
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>'type_001/a_001',filters=>{type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>'type_001/a_001',filters=>{type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP one id - selection 1",__FILE__,__LINE__);

my $output_idtypes=\@leaf_idtypes;
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>'type_001/a_001',
   filters=>{type_002=>'type_002/a_001',type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>'type_001/a_001',
   filters=>{type_002=>'type_002/a_001',type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP one id - selection 2",__FILE__,__LINE__);

my $output_idtypes=\@xyz_idtypes;
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>'type_leaf_001',input_ids=>'type_leaf_001/a_001',
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
   (input_idtype=>'type_leaf_001',input_ids=>'type_leaf_001/a_001',
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP one id - selection 3",__FILE__,__LINE__);

# mutiple ids
my $output_idtypes=\@regular_idtypes;
my @input_ids=map {"type_001/a_$_"} qw(001 002);
my @filter_ids=map {"type_003/a_$_"} qw(001 002);
my $correct=select_ur
  (babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,filters=>{type_003=>\@filter_ids},
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP multiple ids",__FILE__,__LINE__);

# validate
my @input_ids=map {("type_001/a_$_","type_000/valid_$_","type_000/invalid_$_")} qw(001 002);
my $correct=select_ur
  (babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},validate=>0,
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},validate=>0,
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP before validate",__FILE__,__LINE__);

my $correct=select_ur
  (babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},validate=>1,
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},validate=>1,
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP validate",__FILE__,__LINE__);

# select from each idtype
my $output_idtypes=\@regular_idtypes;
for my $input_idtype (@idtypes) {
  my $input_id="$input_idtype/a_001";
  my $correct=select_ur
    (babel=>$babel,input_idtype=>$input_idtype,input_ids=>$input_id,
     output_idtypes=>$output_idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>$output_idtypes);
  cmp_op($actual,$correct,$OP,"$input_idtype $OP one id",__FILE__,__LINE__);
}

done_testing();

