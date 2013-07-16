########################################
# 009.util -- test the testing code - prep_tabledata, now
# maybe more someday
########################################
use t::lib;
use t::utilBabel;
use Carp;
use File::Spec;
use List::MoreUtils qw(uniq);
use List::Util qw(min max);
use Test::More;
use Test::Deep;
use Data::Babel::Config;
use strict;

my $data=new Data::Babel::Config
  (file=>File::Spec->catfile(scriptpath,'handcrafted.data.ini'))->autohash;

my $correct=[['type_001/a_001',undef],
	     [undef,'type_004/a_100'],
	     ['type_001/a_111','type_004/a_111']];
my $actual=prep_tabledata($data->prep_tabledata->data);
cmp_table($actual,$correct,'prep_tabledata - data');

doit('prep_tabledata',3,2);
doit('basics',2,4);
doit('basics_validate_option',6,3);
doit('basics_validate_method',6,3);
doit('basics_all',4,4);
doit('basics_filter',1,4);
doit('filter_undef',2,4);
doit('filter_arrayundef',2,4);
doit('filter_arrayundef_111',3,4);
doit('input_scalar',1,4);
doit('ur_dup_outputs',12,5);
doit('translate_dup_outputs',3,5);
doit('translate_dup_outputs_all',8,5);

done_testing();

sub doit {
  my($key,$count,$width)=@_;
  my($ignore,$file,$line)=caller;
  my $ok=1;
  my $actual=prep_tabledata($data->$key->data);
  $ok&&=is_quietly(scalar @$actual,$count,"prep_tabledata $key - count",$file,$line);
  $ok&&=is_quietly(width($actual),$width,"prep_tabledata $key - width",$file,$line);
  report_pass($ok,"prep_tabledata $key");
}

sub width {
  my($table)=@_;
  return 0 unless @$table;
  my @widths=uniq map {scalar @$_} @$table;
  confess "Table is ragged: widths ",min(@widths),'-',max(@widths) unless scalar @widths==1;
  return $widths[0];
}
