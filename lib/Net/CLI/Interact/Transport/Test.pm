package Net::CLI::Interact::Transport::Test;

use Moose;
with 'Net::CLI::Interact::Role::Transport';

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
    return ('-pe', 'BEGIN { $| = 1 }');
}

1;

# ABSTRACT: Testable CLI connection

=head1 DECRIPTION

This module provides an L<IPC::Run> wrapped instance of Perl which simply
echoes back any input provided. This is used for the L<Net::CLI::Interact>
test suite.

=head1 INTERFACE

=head2 app

Defaults to the value of C<$^X>.

=head2 runtime_options

Returns Perl options which turn it into a C<cat> emulator:

 -pe 'BEGIN { $! = 1 }'

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Role::Transport>

=back

=cut
