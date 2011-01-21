########################################
# 020.chain -- translate. chain schema. 'staggered' & 'binary' data
#   OBSOLETE (030.tree covers this case) but still used. 
########################################
use t::lib;
use t::utilBabel;
use Carp;
use Test::More;
use Test::Deep;
use File::Spec;
use Text::Abbrev;
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;

my($db_type,$num_maptables)=@ARGV;
my %db_type=abbrev qw(staggered binary);
$db_type=$db_type{$db_type} || ' ';
defined $num_maptables or $num_maptables=6;
my $last_maptable=$num_maptables-1;
my $num_links=$num_maptables-1;
my $last_link=$num_links-1;

# create AutoDB database
my $autodb=new Class::AutoDB(database=>'test',create=>1); 
isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;

# make component objects and Babel
# 
# 'link' IdTypes connect MapTables. link type $i_$j connects tables $i, $j ($j=$i+1)
# 'leaf' IdTypes are private to each MapTable
#
# MapTable 0 contains link IdType 0_1, leaf IdType 0
# MapTable $i (0<$i<$last_maptable) contains link IdTypes $i-1_$i, $i_$i+1, leaf $i
# MapTable $last_maptable contains link IdType $i-1_$i, leaf $i
# make explicit Masters for even-numbered leafs
#
my $sql_type='VARCHAR(255)';
my(@idtypes,@masters,@maptables);
for (0..$last_maptable) {	# make leaf IdTypes & Masters
  my $idtype_name='leaf_'.sprintf('%03d',$_);
  push(@idtypes,new Data::Babel::IdType(name=>$idtype_name,sql_type=>$sql_type));
  push(@masters,new Data::Babel::Master(name=>$idtype_name.'_master')) unless $_%2;
}
for (0..$last_link) {		# make link IdTypes
  my($i,$j)=(sprintf('%03d',$_),sprintf('%03d',$_+1));
  my $idtype_name="link_${i}_${j}";
  push(@idtypes,new Data::Babel::IdType(name=>$idtype_name,sql_type=>$sql_type));
}
# make 1st and last MapTables - special cases
my($i,$j)=(sprintf('%03d',0),sprintf('%03d',1));
my $maptable_name="maptable_$i";
push(@maptables,new Data::Babel::MapTable(name=>$maptable_name,idtypes=>"leaf_$i link_${i}_${j}"));
my($i,$j)=(sprintf('%03d',$last_maptable-1),sprintf('%03d',$last_maptable));
my $maptable_name="maptable_$j";
push(@maptables,new Data::Babel::MapTable(name=>$maptable_name,idtypes=>"link_${i}_${j} leaf_$j"));
for (1..$last_maptable-1) { # make regular MapTables
  my($i,$j,$k)=(sprintf('%03d',$_-1),sprintf('%03d',$_),sprintf('%03d',$_+1));
  my $maptable_name='maptable_'.sprintf('%03d',$_);
  push(@maptables,new Data::Babel::MapTable(name=>$maptable_name,
					    idtypes=>"link_${i}_${j} leaf_$j link_${j}_${k}"))
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
for (0..$last_maptable) {
  my $maptable_name='maptable_'.sprintf('%03d',$_);
  my $data=maptable_data($_);
  load_maptable($babel,$maptable_name,$data);
}
for my $master (@{$babel->masters}) {
  my $master_name=$master->name;
  my $data=($master->explicit)? master_data($master): undef;
  load_master($babel,$master_name,$data);
}
load_ur($babel,'ur');

# run the queries. 
#
my @idtypes=@{$babel->idtypes};
my @leafs=grep {$_->name=~/^leaf/} @idtypes;
my @links=grep {$_->name=~/^link/} @idtypes;
@idtypes=(@leafs,@links);

# iterate over all idtypes
for my $input_idtype (@idtypes) {
  my $ok=1;
  $ok&=doit($input_idtype,[],__FILE__,__LINE__);                                  # no outputs
  $ok&=doit($input_idtype,[@idtypes[0..$#idtypes]],__FILE__,__LINE__);            # all
  $ok&=doit($input_idtype,[@leafs[0,int($#leafs/2),$#leafs]],__FILE__,__LINE__);  # triple leafs
  $ok&=doit($input_idtype,[@links[0,int($#links/2),$#links]],__FILE__,__LINE__);  # triple links
  $ok&=doit($input_idtype,[@leafs[1,int($#leafs/2)+1],@links[0,$#links]],__FILE__,__LINE__); 
				                                                  # mixed quad
  for my $j0 (0..$#idtypes-1) {
    $ok&=doit($input_idtype,[@idtypes[$j0]],__FILE__,__LINE__);		          # single
    for my $j1 ($j0+1..$#idtypes) {
      $ok&=doit($input_idtype,[@idtypes[$j0,$j1]],__FILE__,__LINE__);	          # pair
    }}
  report_pass($ok,"$db_type: input=".$input_idtype->name);
}

cleanup_ur($babel);		# clean up intermediate files
done_testing();

# args are idtypes
sub doit {
  my($input_idtype,$output_idtypes,$file,$line)=@_;
  my $input_ids=idtype2ids($input_idtype);

  my $correct=select_ur
    (babel=>$babel,
     input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $actual=$babel->translate
    (input_idtype=>$input_idtype,input_ids=>$input_ids,output_idtypes=>$output_idtypes);
  my $label="$db_type: input_idtype=".$input_idtype->name.
    ', output_idtypes='.join(' ',map {$_->name} @$output_idtypes);
  report_fail(scalar @$correct,"BAD NEWS: \$correct empty. $label",$file,$line);
  cmp_table_quietly($actual,$correct,$label,$file,$line);
#   unless (@$correct && cmp_table($actual,$correct,$label,$file,$line)) {
#     print "break here\n";
#   }
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

# arg is maptable number
sub maptable_data {
  $db_type eq 'staggered'? maptable_data_staggered(@_): maptable_data_binary(@_);
}
# arg can be link number or Master object
sub master_data {
  my $leaf=ref $_[0]? $_[0]->idtype->name: 'leaf_'.sprintf('%03d',$_[0]);
  $db_type eq 'staggered'? master_data_staggered($leaf): master_data_binary($leaf);
}
sub maptable_data_staggered {
  my($i)=@_;
  my $num=sprintf('%03d',$i);
  my $leaf="leaf_$num";
  my @leafs=((map {"$leaf/a_".sprintf('%03d',$_)} ($i..$last_maptable)),
             (map {"$leaf/b_".sprintf('%03d',$last_maptable-$_)} (0..$i)));
  
  my(@data,@link_befores,@link_afters);
  my $link_before=join('_','link',sprintf('%03d',$i-1),$num);
  @link_befores=map {"${link_before}/l_$_"} map {/.*_(\d+)/}  @leafs;
  my $link_after=join('_','link',$num,sprintf('%03d',$i+1));
  @link_afters=map {"${link_after}/l_$_"} map {/.*_(\d+)/}  @leafs;

  if ($i==$last_maptable) {
    @data=(["${link_before}/multi","$leaf/multi_000"],
	   ["${link_before}/multi","$leaf/multi_001"],
	   map {[$link_befores[$_],$leafs[$_]]} (0..$#leafs));
  } elsif($i==0) {
    @data=(["$leaf/multi_000","${link_after}/multi"],
	   ["$leaf/multi_001","${link_after}/multi"],
	   map {[$leafs[$_],$link_afters[$_]]} (0..$#leafs));
  } else {			# general case
    @data=(["${link_before}/multi","$leaf/multi_000","${link_after}/multi"],
	   ["${link_before}/multi","$leaf/multi_001","${link_after}/multi"],
	   map {[$link_befores[$_],$leafs[$_],$link_afters[$_]]} (0..$#leafs));
  }
  \@data;
}
sub master_data_staggered {
  my($leaf)=@_;
  my @leafs=("${leaf}/multi_000","${leaf}/multi_001",
	     map {("${leaf}/a_$_","${leaf}/b_$_")} map {sprintf('%03d',$_)}  (0..$last_maptable));
  \@leafs;
}

sub maptable_data_binary {
  my($i)=@_;
  my @binvals=binary_series($num_maptables,$i);
  my $num=sprintf('%03d',$i);
  my $leaf="leaf_$num";
  my @leafs=map {"$leaf/c_$_"} @binvals;

  my(@data,@link_befores,@link_afters);
  my $link_before=join('_','link',sprintf('%03d',$i-1),$num);
  @link_befores=map {"${link_before}/l_$_"} @binvals;
  my $link_after=join('_','link',$num,sprintf('%03d',$i+1));
  @link_afters=map {"${link_after}/l_$_"} @binvals;
  
  if ($i==$last_maptable) {
    @data=(["${link_before}/multi","$leaf/multi_000"],
	   ["${link_before}/multi","$leaf/multi_001"],
	   map {[$link_befores[$_],$leafs[$_]]} (0..$#leafs));
  } elsif($i==0) {
    @data=(["$leaf/multi_000","${link_after}/multi"],
	   ["$leaf/multi_001","${link_after}/multi"],
	   map {[$leafs[$_],$link_afters[$_]]} (0..$#leafs));
  } else {			# general case
    @data=(["${link_before}/multi","$leaf/multi_000","${link_after}/multi"],
	   ["${link_before}/multi","$leaf/multi_001","${link_after}/multi"],
	   map {[$link_befores[$_],$leafs[$_],$link_afters[$_]]} (0..$#leafs));
  }
  \@data;
}
# arg is link number
sub master_data_binary {
  my($leaf)=@_;
  my @binvals=binary_series($num_maptables);
  my @leafs=("${leaf}/multi_000","${leaf}/multi_001",map {"${leaf}/c_$_"} @binvals);
  \@leafs;
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
# arg is IdType
sub idtype2ids {
  my($idtype)=@_;
  my $name=$idtype->name;
  $name=~/^leaf/? leaf_ids($name): link_ids($name)}

sub leaf_ids {
  $db_type eq 'staggered'? leaf_ids_staggered(@_): leaf_ids_binary(@_);
}
sub link_ids {
  $db_type eq 'staggered'? link_ids_staggered(@_): link_ids_binary(@_);
}
# # arg is maptable index
# sub link_before_ids {
#   my($i)=@_;
#   confess "Bad news: link_before_ids called with \$i=0" if $i==0;
#   my $link_before=join('_','link',sprintf('%03d',$i-1),sprintf('%03d',$i));
#   $db_type eq 'staggered'? link_ids_staggered($link_before): link_ids_binary($link_before);
# }
# sub link_after_ids {
#   my($i)=@_;
#   confess "Bad news: link_before_ids called with \$i=\$last_maptable" if $i==$last_maptable;
#   my $link_after=join('_','link',sprintf('%03d',$i),sprintf('%03d',$i+1));
#   $db_type eq 'staggered'? link_ids_staggered($link_after): link_ids_binary($link_after);
# }

sub leaf_ids_staggered {
   my($leaf)=@_;
   ["${leaf}/none","${leaf}/multi_000","${leaf}/multi_001",
   map {"${leaf}/a_".sprintf('%03d',$_),"${leaf}/b_".sprintf('%03d',$_)} (0..$last_maptable)];
}
sub link_ids_staggered {
  my($link)=@_;
  ["${link}/none","${link}/multi",map {"${link}/l_".sprintf('%03d',$_)} (0..$last_maptable)];
}

sub leaf_ids_binary {
   my($leaf)=@_;
   ["${leaf}/none","${leaf}/multi_000","${leaf}/multi_001",
    map {"${leaf}/c_$_"} binary_series($num_maptables)];
}
sub link_ids_binary {
  my($link)=@_;
  my @binvals=binary_series($num_maptables);
  ["${link}/none","${link}/multi",map {"${link}/l_$_"} @binvals];
}
