########################################
# sanity check database and testing code
########################################
use t::lib;
use t::utilBabel;
use translate_hand;
use Test::More;
use Data::Babel;
use strict;

init();

# test component-object attributes
check_handcrafted_idtypes($babel->idtypes,'mature','Babel attribute: idtypes');
check_handcrafted_masters($babel->masters,'mature','Babel attribute: masters');
check_handcrafted_maptables($babel->maptables,'mature',
			    'Babel attribute: maptables');
my $ok=check_database_sanity($babel,'database',3);

# test ur construction for sanity
my $correct=prep_tabledata($data->ur->data);
is_quietly(scalar @$correct,14,'BAD NEWS: prep_tabledata got wrong number of rows!!');
my @columns=qw(type_001 type_002 type_003 type_004);
push(@columns,qw(_X_type_001 _X_type_002)) if $OPTIONS->history;
my $columns=join(',',@columns);
my $actual=$dbh->selectall_arrayref(qq(SELECT $columns FROM ur));
cmp_table_quietly($actual,$correct,'ur construction');

# test ur selection for sanity
my $correct=prep_tabledata($data->ur_selection->data);
is_quietly(scalar @$correct,11,'BAD NEWS: prep_tabledata got wrong number of rows!!');
my $actual=select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_001 type_004)]);
cmp_table_quietly($actual,$correct,'ur selection');

# basic translate or count test for sanity. also check ur selection
my $id_prefix=!$OPTIONS->history? 'type_001/a_': 'type_001/x_';
my @input_ids=map {"${id_prefix}$_"} qw(000 001 111);
my $correct=prep_tabledata($data->basics->data);
is_quietly(scalar @$correct,2,'BAD NEWS: prep_tabledata got wrong number of rows!!');
my $actual=select_ur(babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
		     output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table_quietly($actual,$correct,"select_ur basic $OP",__FILE__,__LINE__);
my $actual=$babel->$OP(input_idtype=>'type_001',input_ids=>\@input_ids,
		       output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_op($actual,$correct,$OP,"basic $OP",__FILE__,__LINE__);

# basic filter test
my $correct=prep_tabledata($data->basics_filter->data);
is_quietly(scalar @$correct,1,'BAD NEWS: prep_tabledata got wrong number of rows!!');
my $actual=select_ur(babel=>$babel,input_idtype=>'type_001',input_ids=>\@input_ids,
		     filters=>{type_004=>'type_004/a_111'},
		     output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table_quietly($actual,$correct,"select_ur basic $OP w/ filter",__FILE__,__LINE__);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_004=>'type_004/a_111'},output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_op($actual,$correct,$OP,"basic $OP w/ filter (scalar)",__FILE__,__LINE__);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids=>\@input_ids,
   filters=>{type_004=>['type_004/a_111']},
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_op($actual,$correct,$OP,"basic $OP w/ filter (ARRAY)",__FILE__,__LINE__);

# translate all
my $correct=prep_tabledata($data->basics_all->data);
is_quietly(scalar @$correct,4,'BAD NEWS: prep_tabledata got wrong number of rows!!');
my $actual=select_ur(babel=>$babel,input_idtype=>'type_001',input_ids_all=>1,
		     output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table_quietly($actual,$correct,"select_ur basic $OP all",__FILE__,__LINE__);
my $actual=$babel->$OP
  (input_idtype=>'type_001',input_ids_all=>1,
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_op($actual,$correct,$OP,"basic $OP all",__FILE__,__LINE__);

# NG 12-11-20: added tests selecting one row for each input idtype
for my $input_idtype (@idtypes) {
  my $id_prefix=($OPTIONS->history && grep {$input_idtype eq $_} qw(type_001 type_002))? 
    "${input_idtype}/x_": "${input_idtype}/a_";
  my $input_id="${id_prefix}111";
  my $correct=prep_tabledata($data->$input_idtype->data);
  is_quietly(scalar @$correct,1,'BAD NEWS: prep_tabledata got wrong number of rows!!');
  my $actual=select_ur(babel=>$babel,input_idtype=>$input_idtype,input_ids=>$input_id,
		     output_idtypes=>\@idtypes);
  cmp_table_quietly($actual,$correct,"select_ur $input_idtype $OP one row",__FILE__,__LINE__);
  my $actual=$babel->$OP(input_idtype=>$input_idtype,input_ids=>$input_id,
			 output_idtypes=>\@idtypes);
  cmp_op($actual,$correct,$OP,"$input_idtype $OP one row",__FILE__,__LINE__);
}

done_testing();
