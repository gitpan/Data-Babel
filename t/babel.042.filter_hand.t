########################################
# 042.filter_hand -- test filters using handcrafted Babel & components
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use Set::Scalar;
use Getopt::Long;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

# if --developer set, run full test suite. else just a short version
our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(developer));

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
cleanup_db($autodb);		# cleanup database from previous test
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
$babel->load_implicit_masters;
load_ur($babel,'ur');

# test ur construction for sanity
my $correct=prep_tabledata($data->ur->data);
my $actual=$dbh->selectall_arrayref(qq(SELECT type_001,type_002,type_003,type_004 FROM ur));
cmp_table($actual,$correct,'sanity test - ur construction');

# test ur selection for sanity
my $correct=prep_tabledata($data->ur_selection->data);
my $actual=select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_001 type_004)]);
cmp_table($actual,$correct,'sanity test - ur selection');

# now the real tests begin.
# Test all combinations of outputs. Also test with duplicate outputs
# Note that for some cases, outputs will contain input
# For each case, test 1 input that matches nothing, then test 1-all input ids
my @idtypes=qw(type_001 type_002 type_003 type_004);
my $idtypes_subsets=Set::Scalar->new(@idtypes)->power_set;
my @input_idtypes=$OPTIONS{developer}? @idtypes: @idtypes[0,2];
my @output_idtypes=$OPTIONS{developer}?
  map {[$_->members]} grep {$_->size<=2} $idtypes_subsets->members :
  ([],map {[$_],['type_001',$_]} @idtypes);
my @ids=qw(000 001 010 011 100 101 110 111);
for my $input_idtype (@input_idtypes) {
  for my $output_idtypes (@output_idtypes) {
    # $output_idtypes=[$output_idtypes->members];
    while (defined(my $filter_idtypes=$idtypes_subsets->each)) {
      doit_all($input_idtype,$output_idtypes,[$filter_idtypes->members]);
    }
    # now do it with filters turned off
    my $ok=1;
    my $correct=select_ur
      (babel=>$babel,input_idtype=>$input_idtype,output_idtypes=>$output_idtypes);
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>undef,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids absent, undef filters arg, output_idtypes=@$output_idtypes";  
    $ok&&=cmp_table_quietly($actual,$correct,$label) or next;
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>{},output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids absent, empty filters arg, output_idtypes=@$output_idtypes";  
    $ok&&=cmp_table_quietly($actual,$correct,$label) or next;
    report_pass($ok,
		"input=$input_idtype, filters turned off, outputs=".join(',',@$output_idtypes));  
  }
  doit_all($input_idtype,[],[@idtypes,@idtypes]); # duplicate filters
}
# test a big IN clause
my $big=10000;
my $input_idtype='type_001';
my $filter_idtype='type_002';
my @regular_filter_ids=map {$filter_idtype."/a_$_"} @ids;
my @extra_filter_ids=map {"extra_$_"} (0..$big-1);
my $output_idtypes=['type_004'];
my $correct=select_ur
  (babel=>$babel,
   input_idtype=>$input_idtype,filters=>{$filter_idtype=>[@regular_filter_ids]},
   output_idtypes=>$output_idtypes);
my $actual=$babel->translate
  (input_idtype=>$input_idtype,filters=>{$filter_idtype=>[@regular_filter_ids,@extra_filter_ids]},
   output_idtypes=>$output_idtypes);
my $label="big IN clause: size > $big";
cmp_table($actual,$correct,$label);

done_testing();

# handcrafted data not well-suited for complex filter tests, 'cuz most combos give empty results
# so, always test with all input ids, and do select filter combos
sub doit_all {
  my($input_idtype,$output_idtypes,$filter_idtypes)=@_;
  my $ok=1;
  $ok&&=doit($input_idtype,$output_idtypes,$filter_idtypes,['none'],__FILE__,__LINE__) 
    or return 0;
  for my $i (0..$#ids) {
    $ok&&=doit($input_idtype,$output_idtypes,$filter_idtypes,[0..$i],__FILE__,__LINE__) 
      or return 0;
  }
  report_pass($ok,"input=$input_idtype, filters=".join(',',@$filter_idtypes).
	      " outputs=".join(',',@$output_idtypes));
}
# input, outputs, filters are IdTypes
# ids can be 'none' or array indices
sub doit {
  my($input_idtype,$output_idtypes,$filter_idtypes,$ids,$file,$line)=@_;
  my @input_ids=map {$input_idtype."/a_$_"} @ids; # all input ids
  my $ok=1;
  my %filters;
  for my $filter_idtype (@$filter_idtypes) {
    # NG 12-09-21: line below obviously wrong... scary that not caught sooner
    # my @filter_ids=[map {/\D/? $_: $filter_idtype.'/a_'.$ids[$_]} @$ids];
    my @filter_ids=map {/\D/? $_: $filter_idtype.'/a_'.$ids[$_]} @$ids;
    $filters{$filter_idtype}=\@filter_ids;
  }
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>\@input_ids,filters=>\%filters,
     output_idtypes=>$output_idtypes);
  # way too many cases yield empty results. skip most of them
  # return($ok) unless scalar(@$correct)||$ids->[0] eq 'none';
  if (scalar(@$correct)||$ids->[0] eq 'none') {
    # print "correct size=",scalar @$correct,"\n";
    # do it with all input_ids
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,input_ids=>\@input_ids,filters=>\%filters,
       output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, all input_ids, filter_idtypes=@$filter_idtypes, filter_ids=@$ids, output_idtypes=@$output_idtypes";
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
    # do it again with input_ids absent
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>\%filters,
       output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids absent, filter_idtypes=@$filter_idtypes, filter_ids=@$ids, output_idtypes=@$output_idtypes";  
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
  }
  if (@$filter_idtypes) {
    # do it with undef added to one filter
    my $filter_idtype=$filter_idtypes->[0];
    my $list=$filters{$filter_idtype};
    push(@$list,undef);
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids absent, $filter_idtype contains undef, filter_idtypes=@$filter_idtypes, filter_ids=@$ids, output_idtypes=@$output_idtypes";  
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
    # do it with one filter=>undef
    $filters{$filter_idtype}=undef;
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids absent, $filter_idtype=>undef,filter_idtypes=@$filter_idtypes, filter_ids=@$ids, output_idtypes=@$output_idtypes";  
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
    
    # do it with all filter=>undef
    my %filters=map {$_=>undef} @$filter_idtypes;
    my $correct=select_ur
      (babel=>$babel,
       input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $actual=$babel->translate
      (input_idtype=>$input_idtype,filters=>\%filters,output_idtypes=>$output_idtypes);
    my $label="input_idtype=$input_idtype, input_ids absent, all filters undef,filter_idtypes=@$filter_idtypes, filter_ids=@$ids, output_idtypes=@$output_idtypes";  
    $ok&&=cmp_table_quietly($actual,$correct,$label,$file,$line) or return 0;
  }
  $ok;
}
