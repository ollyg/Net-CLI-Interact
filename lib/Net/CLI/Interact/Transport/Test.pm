package # hide from pause
    Net::CLI::Interact::Transport::Test::Options;
use Moose;

use Moose::Util::TypeConstraints;
coerce 'Net::CLI::Interact::Transport::Test::Options'
    => from 'HashRef[Any]'
        => via { Net::CLI::Interact::Transport::Test::Options->new($_) };

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

package Net::CLI::Interact::Transport::Test;

use Moose;
with 'Net::CLI::Interact::Role::Transport';

has 'connect_options' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport::Test::Options',
    default => sub { {} },
    coerce => 1,
    required => 1,
);

has 'app' => (
    is => 'ro',
    isa => 'Str',
    default => $^X,
    required => 0,
);

#sub _which_perl {
#    use Config;
#    $secure_perl_path = $Config{perlpath};
#    if ($^O ne 'VMS')
#        {$secure_perl_path .= $Config{_exe}
#            unless $secure_perl_path =~ m/$Config{_exe}$/i;}
#    return $secure_perl_path;
#}

sub runtime_options {
    return ('-ne', 'BEGIN { $| = 1 }; print $_, time, "\nPROMPT>\n";');
}

1;

# ABSTRACT: Testable CLI connection

=head1 DECRIPTION

This module provides an L<IPC::Run> wrapped instance of Perl which simply
echoes back any input provided. This is used for the L<Net::CLI::Interact>
test suite.

=head1 INTERFACE

=head2 app

Defaults to the value of C<$^X> (that is, Perl itself).

=head2 runtime_options

Returns Perl options which turn it into a CLI emulator:

 -ne 'BEGIN { $| = 1 }; print $_, time, "\nPROMPT>\n";'

For example:

 some command
 some command
 1301578196
 PROMPT>

In this case the output command was "some command" which was echoed, followed
by the dummy command output (epoch seconds), followed by a "prompt".

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Role::Transport>

=back

=cut
