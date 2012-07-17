package Net::CLI::Interact::Transport::Telnet;
{
  $Net::CLI::Interact::Transport::Telnet::VERSION = '1.121990_002';
}

use Moose;
extends 'Net::CLI::Interact::Transport';

{
    package # hide from pause
        Net::CLI::Interact::Transport::Telnet::Options;
    use Moose;
    extends 'Net::CLI::Interact::Transport::Options';

    has 'host' => (
        is => 'rw',
        isa => 'Str',
        required => 1,
    );

    has 'port' => (
        is => 'rw',
        isa => 'Int',
        required => 0,
        default => 23,
    );

    has 'opts' => (
        is => 'rw',
        isa => 'ArrayRef[Any]',
        required => 0,
        default => sub { [] },
    );

    use Moose::Util::TypeConstraints;
    coerce 'Net::CLI::Interact::Transport::Telnet::Options'
        => from 'HashRef[Any]'
            => via { Net::CLI::Interact::Transport::Telnet::Options->new($_) };
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# allow native use of Net::Telnet on Unix
if (not Net::CLI::Interact::Transport::is_win32()) {
    has '+use_net_telnet_connection' => ( default => 1 );
}

has 'connect_options' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport::Telnet::Options',
    coerce => 1,
    required => 1,
);

sub _build_app {
    my $self = shift;
    confess "please pass location of plink.exe in 'app' parameter to new()\n"
        if $self->is_win32;
    return 'Net::Telnet'; # unix, but unused
}

sub runtime_options {
    my $self = shift;
    if ($self->is_win32) {
        return (
            '-telnet',
            '-P', $self->connect_options->port,
            @{$self->connect_options->opts},
            $self->connect_options->host,
        );
    }
    else {
        return (
            Host => $self->connect_options->host,
            Port => $self->connect_options->port,
            @{$self->connect_options->opts},
        );
    }
}

1;

# ABSTRACT: TELNET based CLI connection


__END__
=pod

=head1 NAME

Net::CLI::Interact::Transport::Telnet - TELNET based CLI connection

=head1 VERSION

version 1.121990_002

=head1 DECRIPTION

This module provides a wrapped instance of a TELNET client for use by
L<Net::CLI::Interact>.

=head1 INTERFACE

=head2 app

On Windows platforms you B<must> download the C<plink.exe> program, and pass its
location to the library in this parameter. On other platforms, this defaults to
C<telnet>.

=head2 runtime_options

Based on the C<connect_options> hash provided to Net::CLI::Interact on
construction, selects and formats parameters to provide to C<app> on the
command line. Supported attributes:

=over 4

=item host (required)

Host name or IP address of the host to which the TELNET application is to
connect.

=item port

Port number on the host which is listening for the TELNET connection.
Defaults to 23.

=item reap

Only used on Unix platforms, this installs a signal handler which attempts to
reap the C<ssh> child process. Pass a true value to enable this feature only
if you notice zombie processes are being left behind after use.

=item opts

If you want to pass any other options to the Telnet application, then use
this option, which should be an array reference.

On Windows platforms, each item on the list will be passed to the C<plink.exe>
application, separated by a single space character. On Unix platforms, the
L<Net::Telnet library is used for TELNET connections, so the list can be any
option taken by its C<new()> constructor.

=back

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Transport>

=back

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

