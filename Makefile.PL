
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Adds CPAN Testers reporting to CPAN.pm',
  'AUTHOR' => 'David Golden <dagolden@cpan.org>',
  'BUILD_REQUIRES' => {
    'Archive::Tar' => '1.54',
    'File::Copy::Recursive' => '0.35',
    'File::Spec::Functions' => '0',
    'File::pushd' => '0.32',
    'IO::CaptureOutput' => '1.03',
    'Test::Harness' => '0',
    'Test::More' => '0.62'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.30'
  },
  'DISTNAME' => 'CPAN-Reporter',
  'EXE_FILES' => [],
  'LICENSE' => 'apache',
  'NAME' => 'CPAN::Reporter',
  'PREREQ_PM' => {
    'CPAN' => '1.9301',
    'CPAN::Version' => '0',
    'Capture::Tiny' => '0',
    'Carp' => '0',
    'Config' => '0',
    'Config::Tiny' => '2.08',
    'Devel::Autoflush' => '0.04',
    'Exporter' => '0',
    'ExtUtils::MakeMaker' => '6.36',
    'Fcntl' => '0',
    'File::Basename' => '0',
    'File::Find' => '0',
    'File::Glob' => '0',
    'File::HomeDir' => '0.58',
    'File::Path' => '0',
    'File::Spec' => '3.19',
    'File::Temp' => '0.16',
    'IO::File' => '0',
    'IPC::Cmd' => '0.46',
    'Parse::CPAN::Meta' => '0',
    'Probe::Perl' => '0',
    'Test::Reporter' => '1.54',
    'constant' => '0',
    'vars' => '0'
  },
  'VERSION' => '1.2001',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



