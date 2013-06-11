########################################
# explore the problem of pseudo duplicate rows
# in this example, we have rows that are identical on all non-null columns
#      gene_symbol  organism_name  gene_entrez  probe_id
#      HTT          human          3064         A_23_P212749
#      HTT          human          3064
#      Htt          rat            29424
#      Htt          mouse          15194
#      Htt          mouse          15194        A_55_P2088530
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
cleanup_db($autodb);		# cleanup database from previous test
Data::Babel->autodb($autodb);
my $dbh=$autodb->dbh;
my $confpath=File::Spec->catfile(scriptpath,scriptbasename.'.dir');

# make component objects and Babel. note that $masters is for EXPLICIT masters only
my $idtypes=new Data::Babel::Config
  (file=>File::Spec->catfile($confpath,scriptcode.'.idtype.ini'))->objects('IdType');
my $masters=new Data::Babel::Config
  (file=>File::Spec->catfile($confpath,scriptcode.'.master.ini'))->objects('Master');
my $maptables=new Data::Babel::Config
  (file=>File::Spec->catfile($confpath,scriptcode.'.maptable.ini'),tt=>1)->objects('MapTable');
my $babel=new Data::Babel
  (name=>'test',idtypes=>$idtypes,masters=>$masters,maptables=>$maptables);
isa_ok($babel,'Data::Babel','sanity test - $babel');

# my @idtypes=map {new Data::Babel::IdType(name=>"type_$_",sql_type=>'VARCHAR(255)')} (1,2,3);
# my @masters=map {new Data::Babel::Master(name=>"type_${_}_master",babel=>'test')} (1);
# my @maptables=
#   (new Data::Babel::MapTable(name=>'maptable_12',idtypes=>'type_1 type_2',babel=>'test'),
#    new Data::Babel::MapTable(name=>'maptable_23',idtypes=>'type_2 type_3',babel=>'test'));
# my $babel=new Data::Babel
#   (name=>'test',idtypes=>\@idtypes,masters=>\@masters,maptables=>\@maptables);
# isa_ok($babel,'Data::Babel','class is Data::Babel - sanity check');

# setup the database
my $data=new Data::Babel::Config
  (file=>File::Spec->catfile($confpath,scriptcode.'.data.ini'))->autohash;
for my $name(qw(gene_transcript probe_transcript gene_entrez gene_info)) {
  load_maptable($babel,$name,$data->$name->data);
}
# no explicit masters
$babel->load_implicit_masters;

# real tests start here
load_ur($babel,'ur');
my $output_idtypes=[qw(organism_name gene_entrez probe_id)];
my $correct=select_ur
  (babel=>$babel,input_idtype=>'gene_symbol',input_ids=>'htt',output_idtypes=>$output_idtypes);
my $actual=$babel->translate
  (input_idtype=>'gene_symbol',input_ids=>'htt',output_idtypes=>$output_idtypes);

# TODO: test fails because of case sensitive matching in filter_ur
#       I don't want to fix this yet, because who knows what else it will break...
# TODO: test exhibits the observed behavior: namely pseudo-dups are returned
#       figure out whether to fix, and if so, how.
#       then change select_ur - this test should fail for real
#       then fix translate...

cmp_table($actual,$correct,'translate');

done_testing();
