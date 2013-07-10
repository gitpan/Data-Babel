########################################
# test all methods in basic fashion
# adapted from babel.040.translate_hand
# almost identical to 010.basics.t
########################################
use t::lib;
use t::utilBabel;
use pdups_hand;
use Test::More;
use Data::Babel;
use strict;

init();
my $output_idtypes=\@regular_idtypes;;
my $id_prefix=!$OPTIONS->history? 'type_001/a_': 'type_001/x_';

#  translate, count
my $input_id="${id_prefix}001";
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>$input_id,filters=>{type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>$input_id,filters=>{type_003=>'type_003/a_001'},
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP one id - selection 1",__FILE__,__LINE__);

my $input_id="${id_prefix}111";
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>'type_001',input_ids=>$input_id,filters=>{type_003=>'type_003/a_111'},
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>$input_id,filters=>{type_003=>'type_003/a_111'},
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP one id - selection 2",__FILE__,__LINE__);

my @input_ids=map {"${id_prefix}$_"} qw(000 001 111);
my @filter_ids=map {"type_003/a_$_"} qw(000 001 111);
my $correct=select_ur
  (babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,filters=>{type_003=>\@filter_ids},
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP multiple ids",__FILE__,__LINE__);

# validate - 001, 111 valid
my @input_ids=map {"${id_prefix}$_"} qw(000 001 110 111);
my $correct=select_ur
  (babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},validate=>1,
   output_idtypes=>$output_idtypes);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_003=>\@filter_ids},validate=>1,
   output_idtypes=>$output_idtypes);
cmp_op($actual,$correct,$OP,"$OP validate",__FILE__,__LINE__);

# select from each regular idtype
my $output_idtypes=\@regular_idtypes;
for my $input_idtype (@regular_idtypes) {
  my $id_prefix=($OPTIONS->history && grep {$input_idtype eq $_} qw(type_001 type_002))? 
    "${input_idtype}/x_": "${input_idtype}/a_";
  my $input_id="${id_prefix}111";
  my $correct=select_ur
    (babel=>$babel,input_idtype=>$input_idtype,input_ids=>$input_id,
     output_idtypes=>$output_idtypes);
  my $actual=$babel->$OP
    (input_idtype=>$input_idtype,input_ids=>$input_id,output_idtypes=>$output_idtypes);
  cmp_op($actual,$correct,$OP,"$input_idtype $OP one id w/o 'multi' outputs",__FILE__,__LINE__);
}

done_testing();
