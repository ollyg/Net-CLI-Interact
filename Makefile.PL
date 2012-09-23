use strict;
use warnings;

use ExtUtils::MakeMaker 6.30;

my %WriteMakefileArgs = (
##{ $plugin->get_default(keys %default_args) ##}
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

if ( $^O =~ m/^(?!Win32)/ ) {
  $WriteMakefileArgs{CONFIGURE_REQUIRES}{'ExtUtils::CBuilder'} = 0;

  eval 'require ExtUtils::CBuilder;';
  if (not $@) {
    my $builder = ExtUtils::CBuilder->new( quiet => 1 );
    if ($builder->have_compiler) {
        $WriteMakefileArgs{PREREQ_PM}{'IO::Pty'} = '0';
    }
  }
}

WriteMakefile(%WriteMakefileArgs);
