########################################
# 010.star -- translate. star schema. 'staggered' & 'binary' data
#   OBSOLETE (030.tree covers this case) but still used. 
########################################
use t::lib;
use t::utilBabel;
use Test::More;
use Test::Deep;
use File::Spec;
use Text::Abbrev;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

my($db_type,$num_points)=@ARGV;
my %db_type=abbrev qw(staggered binary);
$db_type=$db_type{$db_type} || ' ';
defined $num_points or $num_points=6;
my $last_point=$num_points-1;

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
cleanup_db($autodb);		# cleanup database from previous test
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

# make component objects and Babel
#
# make 1 central IdType and 1 IdType per point. 
# make explicit Masters for even-numbered points
# make 1 MapTable per point
#
my $sql_type='VARCHAR(255)';
my(@idtypes,@masters,@maptables);
push(@idtypes,new Data::Babel::IdType(name=>'center',sql_type=>$sql_type));
for (0..$last_point) {
  my $idtype_name='point_'.sprintf('%03d',$_);
  push(@idtypes,new Data::Babel::IdType(name=>$idtype_name,sql_type=>$sql_type));
  push(@masters,new Data::Babel::Master(name=>$idtype_name.'_master')) unless $_%2;
  my $maptable_name='maptable_'.sprintf('%03d',$_);
  push(@maptables,new Data::Babel::MapTable(name=>$maptable_name,idtypes=>"center $idtype_name"));
}

my $babel=new Data::Babel
  (name=>'test',idtypes=>\@idtypes,masters=>\@masters,maptables=>\@maptables);
isa_ok($babel,'Data::Babel','sanity test - $babel');
my @errstrs=$babel->check_schema;
ok(!@errstrs,'sanity test - check_schema');
diag(join("\n",@errstrs)) if @errstrs;
# $babel->show;

# setup the database
#
# 'center' is the important IdType. assume for concreteness $num_points=10
# 'center' has 10 'a' values : a_001..a_009
#   the same 'b' values: b_001..b_009
#   a single value 'multi' used to test n-n joins
# MapTable $i has 'center' values a_$i..a_9, b_9..b_(10-$i)
#   each 'center' value matched with corresponding 'point' value: eg, p_001
# explicit Masters have p_000..p_009, p_none
#
for (0..$last_point) {
  my $maptable_name='maptable_'.sprintf('%03d',$_);
  my $data=maptable_data($_);
  load_maptable($babel,$maptable_name,$data);
}
# NG 12-09-30: use load_implicit_masters
$babel->load_implicit_masters;
for my $master (@{$babel->masters}) {
  next if $master->implicit;
  my $master_name=$master->name;
  # my $data=($master->explicit)? master_data($master): undef;
  my $data=master_data($master);
  load_master($babel,$master_name,$data);
}
load_ur($babel,'ur');

# run the queries. 
#
# input: center; outputs: none, all, 1 triple, all singles, all pairs,
# input: point; outputs: same as above w/ and w/o center
#
my @points=map {'point_'.sprintf('%03d',$_)} (0..$last_point);

# queries w/ input=center
my $ok=1;
$ok&=doit_all('center');		    # no outputs
$ok&=doit_all('center',0..$last_point);  # all
$ok&=doit_all('center',0,int($last_point/2),$last_point);  # 1 triple
for my $j0 (0..$last_point-1) {
  $ok&=doit_all('center',$j0);	    # single
  for my $j1 ($j0+1..$last_point) {
    $ok&=doit_all('center',$j0,$j1);	    # pair
  }}
report_pass($ok,"$db_type: input=center");
# queries w/ input=points. doit_all knows to include center
for my $i (0..$last_point) {
  my $ok=1;
  $ok&=doit_all($i);			    # no outputs
  $ok&=doit_all($i,0..$last_point);	    # all
  $ok&=doit_all($i,0,int($last_point/2),$last_point);  # 1 triple
  for my $j0 (0..$last_point-1) {
    $ok&=doit_all($i,$j0);		    # single
    for my $j1 ($j0+1..$last_point) {
      $ok&=doit_all($i,$j0,$j1);	    # pair
    }}
  report_pass($ok,"$db_type: input=$points[$i]");
}

done_testing();

# args can be 'center' or point indices
sub doit_all {
  my($input,@outputs)=@_;
  my $ok=1;
  $ok&=doit($input,\@outputs,__FILE__,__LINE__) or return 0;
  unless ('center' eq $input) {
    $ok&=doit($input,['center',@outputs],__FILE__,__LINE__) or return 0;
  }
#   report_pass
#     ($ok,"input=$input, outputs=".join(',',@outputs,('center' ne $input? '+/-center':())));
  1;
}
# args can be 'center' or point indices
sub doit {
  my($input,$outputs,$file,$line)=@_;

  my $input_idtype=idx2idtype($input);
  my $output_idtypes=[map {idx2idtype($_)} @$outputs];
  my $input_ids=idx2ids($input);

  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $actual=$babel->translate
    (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $label="$db_type: input_idtype=$input_idtype, output_idtypes=@$output_idtypes";
  report_fail(scalar @$correct,"BAD NEWS: \$correct empty. $label",$file,$line); 
  cmp_table_quietly($actual,$correct,$label,$file,$line);
  # NG 11-01-21: added 'translate all'
  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>$output_idtypes);
  my $actual=$babel->translate
    (input_idtype=>$input_idtype,input_ids_all=>1,output_idtypes=>$output_idtypes);
  $label.=', input_ids_all';
  report_fail(scalar @$correct,"BAD NEWS: \$correct empty. $label",$file,$line); 
  cmp_table_quietly($actual,$correct,$label,$file,$line);

}
sub idx2idtype {($_[0] eq 'center')? 'center': 'point_'.sprintf('%03d',$_[0])}

# arg is point number
sub maptable_data {
  $db_type eq 'staggered'? maptable_data_staggered(@_): maptable_data_binary(@_);
}
# arg can be point number or Master object
sub master_data {
  my $point=ref $_[0]? $_[0]->idtype->name: 'point_'.sprintf('%03d',$_[0]);
  $db_type eq 'staggered'? master_data_staggered($point): master_data_binary($point);
}
sub maptable_data_staggered {
  my($i)=@_;
  my @centers=((map {'center/a_'.sprintf('%03d',$_)} ($i..$last_point)),
	       (map {'center/b_'.sprintf('%03d',$last_point-$_)} (0..$i)));
  my $point='point_'.sprintf('%03d',$i);
  my @points=map {"${point}/p_$_"} map {/.*_(\d+)/}  @centers;
  my @data=(['center/multi',"${point}/multi_000"],['center/multi',"${point}/multi_001"],
	    map {[$centers[$_],$points[$_]]} (0..$#centers));
  \@data;
}
sub master_data_staggered {
  my($point)=@_;
  my @points=("${point}/none","${point}/multi_000","${point}/multi_001",
	      map {"${point}/p_$_"} map {sprintf('%03d',$_)}  (0..$last_point));
  \@points;
}

sub maptable_data_binary {
  my($i)=@_;
  my @binvals=binary_series($num_points,$i);
  my @centers=map {"center/c_$_"} @binvals;
  my $point='point_'.sprintf('%03d',$i);
  my @points=map {"${point}/p_$_"} @binvals;
  my @data=(['center/multi',"${point}/multi_000"],['center/multi',"${point}/multi_001"],
	    map {[$centers[$_],$points[$_]]} (0..$#centers));
  \@data;
}
# arg is point number
sub master_data_binary {
  my($point)=@_;
  my @binvals=binary_series($num_points);
  my @points=("${point}/none","${point}/multi_000","${point}/multi_001",
	      map {"${point}/p_$_"} @binvals);
  \@points;
}

sub binary_series {
  my($bits,$my_bit)=@_;
  if (defined $my_bit) {	# return $bits-wide numbers with $my_bit set
    my $mask=1<<$my_bit;
    return map {sprintf '%0*b',$bits,$_} grep {$_&$mask} (0..2**$bits-1);
  } else {			# return all $bits-wide numbers
    return map {sprintf '%0*b',$bits,$_} (0..2**$bits-1);
  }
}
# for debugging. args are number of bits, and number to convert
sub as_binary_string {sprintf '%0*b',@_}

# these functions generate lists of input ids
sub idx2ids {$_[0] eq 'center'? center_ids(): point_ids($_[0])}

sub center_ids {
  $db_type eq 'staggered'? center_ids_staggered(): center_ids_binary();
}
sub point_ids {
  my $point='point_'.sprintf('%03d',$_[0]);
  $db_type eq 'staggered'? point_ids_staggered($point): point_ids_binary($point);
}

sub center_ids_staggered {
  ['center/none','center/multi',
   map {'center/a_'.sprintf('%03d',$_),'center/b_'.sprintf('%03d',$_)} (0..$last_point)];
}
sub point_ids_staggered {
  my($point)=@_;
  ["${point}/none","${point}/multi_000","${point}/multi_001",
   map {"${point}/p_".sprintf('%03d',$_)} (0..$last_point)];
}

sub center_ids_binary {
  ['center/none','center/multi',map {"center/c_$_"} binary_series($num_points)];
}
sub point_ids_binary {
  my($point)=@_;
  my @binvals=binary_series($num_points);
  ["${point}/none","${point}/multi_000","${point}/multi_001",
   map {"${point}/p_$_"} @binvals];
}
