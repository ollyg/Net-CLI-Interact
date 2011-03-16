package Net::CLI::Interact::Transport::Telnet;

use Moose;
with 'Net::CLI::Interact::Role::Transport';

has 'app' => (
    is => 'ro',
    isa => 'Str',
    default => sub { 'telnet' },
    required => 0,
);

sub runtime_options {
    # simple, for now
    return (shift)->transport_options->{host};
}

1;

# ABSTRACT: TELNET based CLI connection

=head1 DECRIPTION

This module provides an L<IPC::Run> wrapped instance of the TELNET application
for use by L<Net::CLI::Interact>.

=head1 INTERFACE

=head2 app

Defaults to C<telnet> but can be changed to the name of the local application
which provides TELNET.

=head2 runtime_options

Based on the C<transport_options> provided to C<Net::CLI::Interact> on
construction, selects hash keys to provide to C<app> on the command line.
Supported keys:

=over 4

=item host

Host name or IP address of the host to which the TELNET application is to
connect.

=back

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Role::Transport>

=back

=cut
