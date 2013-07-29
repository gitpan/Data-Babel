use strict;
use warnings;
use Module::Build;
use DBI;

use lib qw(t);
use t::Build;			# my Module::Build subclass
my $class='t::Build';

# CAUTION: may not work to have DBD::mysql in prereqs. 
#  in past, saw bug where if DBD::mysq not present, install tries to install 'DBD'
#  which does not exist

my $builder = $class->new
  (module_name         => 'Data::Babel',
   license             => 'perl',
   dist_author         => q{Nat Goodman <natg@shore.net>},
   configure_requires=>{'DBI' => 1.604,
			'Module::Build' => 0.4,
		       },
   build_requires =>   {'Benchmark' => 1.12,
			'Carp' => 1.20,
			'Class::AutoClass' => 1.55,
			'Class::AutoDB' => 1.26,
			'Config::IniFiles' => 2.57,
			'Cwd' => 3.26,
                        'DBD::mysql'=> 4.022,
			'DBI' => 1.604,
			'Exporter' => 5.65,
			'File::Basename' => 0,
			'File::Spec' => 3.33,
			'File::Spec::Functions' => 3.33,
			'FindBin' => 1.50,
			'Getopt::Long' => 2.38,
			'Graph' => 0.91,
			'Hash::AutoHash' => 1.16,
			'Hash::AutoHash::Args' => 1.16,
			'Hash::AutoHash::MultiValued' => 1.16,
			'List::MoreUtils' => 0.33,
			'List::Util' => 1.23,
			'Math::BaseCalc' => 1.014,
			'POSIX' => 1.24,
			'Set::Scalar' => 1.25,
			'Scalar::Util' => 1.23,
			'TAP::Harness' => 3.23,
			'Test::Deep' =>  0.11,
			'Test::More' => 0.98,
			'Test::mysqld' => 0.15,
			'Text::Abbrev' => 1.01,
			'Tie::ToObject' => 0.03,
		       },
   requires =>         {'Carp' => 1.20,
			'Class::AutoClass' => 1.55,
			'Class::AutoDB' => 1.26,
			'Class::Singleton' => 1.4,
			'Config::IniFiles' => 2.77,
			'DBD::mysql'=> 4.022,
			'DBI' => 1.621,
			'File::Basename' => 0,
			'File::Spec' => 3.33,
			'Graph' => 0.94,
			'Hash::AutoHash' => 1.16,
			'Hash::AutoHash::Args' => 1.16,
			'Hash::AutoHash::MultiValued' => 1.16,
			'List::MoreUtils' => 0.33,
			'Template' => 2.22,
			'Tie::ToObject' => 0.03,
			'Tree::Trie' => 1.9,
		       },
   recommends =>       {'List::BinarySearch' => 0.11,
			'Tree::RB' => 0.500003,
			},
   create_makefile_pl => 'small',
   extra_compiler_flags => ['-DUSE_PPPORT_H'],
   use_tap_harness => 1,			  
   test_files => 't/babel.*.t',
  );

$builder->create_build_script();
