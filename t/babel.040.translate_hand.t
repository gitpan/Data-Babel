########################################
# 010.basics -- translate mechanics using handcrafted Babel & components
# more challenging translations tested separately
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

# create Babel directly from config files. this is is the usual case
my $name='test';
my $babel=new Data::Babel
  (name=>$name,
   idtypes=>File::Spec->catfile(scriptpath,'handcrafted.idtype.ini'),
   masters=>File::Spec->catfile(scriptpath,'handcrafted.master.ini'),
   maptables=>File::Spec->catfile(scriptpath,'handcrafted.maptable.ini'));
isa_ok($babel,'Data::Babel','sanity test - Babel created from config files');

# test simple attributes
is($babel->name,$name,'sanity test - Babel attribute: name');
is($babel->id,"babel:$name",'sanity test - Babel attribute: id');
is($babel->autodb,$autodb,'sanity test - Babel attribute: autodb');
#is($babel->log,$log,'Babel attribute: log');
# test component-object attributes
check_handcrafted_idtypes($babel->idtypes,'mature','sanity test - Babel attribute: idtypes');
check_handcrafted_masters($babel->masters,'mature','sanity test - Babel attribute: masters');
check_handcrafted_maptables($babel->maptables,'mature',
			    'sanity test - Babel attribute: maptables');

# setup the database
my $data=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.data.ini'))->autohash;
load_handcrafted_maptables($babel,$data);
load_handcrafted_masters($babel,$data);
load_ur($babel,'ur');

# test ur construction for sanity
my $correct=prep_tabledata($data->ur->data);
my $actual=$dbh->selectall_arrayref(qq(SELECT type_001,type_002,type_003,type_004 FROM ur));
cmp_table($actual,$correct,'sanity test - ur construction');

# test ur selection for sanity
my $correct=prep_tabledata($data->ur_selection->data);
my $actual=select_ur(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_001 type_004)]);
cmp_table($actual,$correct,'sanity test - ur selection');

# redo basic translate test for sanity
my $correct=prep_tabledata($data->basics->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids=>[qw(type_001/a_000 type_001/a_001 type_001/a_111)],
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'sanity test - basic translate');
# NG 11-10-21: added translate all
my $correct=prep_tabledata($data->basics_all->data);
my $actual=$babel->translate
  (input_idtype=>'type_001',input_ids_all=>1,
   output_idtypes=>[qw(type_002 type_003 type_004)]);
cmp_table($actual,$correct,'sanity test - basic translate all');

# now the real tests begin.
# for every input do 0-4+ outputs
#   for each case, test 1 input that matches nothing, then test 1-all input ids
#     NG 10-11-08: for each case, test w/o limit and with limits of 0,1,2
#     NG 11-01-21: for each case, test input_ids_all
# for some cases, outputs will contain input
# with >4 outputs, some guaranteed to be duplicates
my @idtypes=qw(type_001 type_002 type_003 type_004);
my @ids=qw(000 001 010 011 100 101 110 111);
for my $i (0..3) {
  doit_all($i);			# no outputs
  doit_all($i,0);
  doit_all($i,0,1);
  doit_all($i,0,1,2);
  doit_all($i,0,1,2,3);
  doit_all($i,0,1,2,3,3,2,1,0);
}
# test a big IN clause
my $big=10000;
my $input_idtype='type_001';
my @regular_input_ids=map {$input_idtype."/a_$_"} @ids;
my @extra_input_ids=map {"extra_$_"} (0..$big-1);
my $output_idtypes=['type_004'];
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>$input_idtype,input_ids=>[@regular_input_ids],output_idtypes=>$output_idtypes);
my $actual=$babel->translate
  (input_idtype=>$input_idtype,input_ids=>[@regular_input_ids,@extra_input_ids],
   output_idtypes=>$output_idtypes);
my $label="big IN clause: size > $big";
cmp_table($actual,$correct,$label);

cleanup_ur($babel);		# clean up intermediate files
done_testing();

sub doit_all {
  my($input,@outputs)=@_;
  my $ok=1;
  $ok&&=doit($input,['none'],\@outputs,__FILE__,__LINE__) or return 0;
  $ok&&=doit($input,'all',\@outputs,__FILE__,__LINE__) or return 0;
 for my $i (0..$#ids) {
    $ok&&=doit($input,[0..$i],\@outputs,__FILE__,__LINE__) or return 0;
  }
  report_pass($ok,"input=$input, outputs=".join(',',@outputs));
}
# input & outputs are array indices - not actual IdTypes
# ids can be 'none' or array indices
sub doit {
  my($input,$ids,$outputs,$file,$line)=@_;
  my $input_idtype=$idtypes[$input];
  my $output_idtypes=[@idtypes[@$outputs]];
  my $ok=1;
  if (ref $ids) {		# usual case: list of ids
    my $input_ids=[map {/\D/? $_: $input_idtype.'/a_'.$ids[$_]} @$ids];
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@$output_idtypes";
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
    # NG 10-11-08: test with limits of 0,1,2
    for my $limit (0,1,2) {
      my $actual=$babel->translate
	(input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes,
	 limit=>$limit);
      my $label="input_idtype=$input_idtype, input_ids=@$input_ids, output_idtypes=@$output_idtypes, limit=$limit";
      $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line,$limit) or return 0;
    }
  } else {			# NG 11-01-21: test input_ids_all
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>$output_idtypes);
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids_all, output_idtypes=@$output_idtypes";
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
  }
  $ok;
}
# # return true if args all different
# sub different {
#   my %uniq=map {$_=>1} @_;
#   scalar(keys %uniq)==scalar @_? 1: 0;
# }
