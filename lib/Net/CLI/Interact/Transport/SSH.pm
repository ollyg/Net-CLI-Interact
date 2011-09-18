package Net::CLI::Interact::Transport::SSH;
BEGIN {
  $Net::CLI::Interact::Transport::SSH::VERSION = '1.112610';
}

use Moose;
extends 'Net::CLI::Interact::Transport';

{
    package # hide from pause
        Net::CLI::Interact::Transport::SSH::Options;
    use Moose;
    extends 'Net::CLI::Interact::Transport::Options';

    has 'host' => (
        is => 'rw',
        isa => 'Str',
        required => 1,
    );

    has 'username' => (
        is => 'rw',
        isa => 'Str',
        required => 0,
        predicate => 'has_username',
    );

    has 'shkc' => (
        is => 'rw',
        isa => 'Bool',
        required => 0,
        default => 1,
    );

    has 'opts' => (
        is => 'rw',
        isa => 'ArrayRef[Any]',
        required => 0,
        default => sub { [] },
    );

    use Moose::Util::TypeConstraints;
    coerce 'Net::CLI::Interact::Transport::SSH::Options'
        => from 'HashRef[Any]'
            => via { Net::CLI::Interact::Transport::SSH::Options->new($_) };
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

has 'connect_options' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport::SSH::Options',
    coerce => 1,
    required => 1,
);

sub _build_app {
    my $self = shift;
    confess "please pass location of plink.exe in 'app' parameter to new()\n"
        if $self->is_win32;
    return 'ssh';
}

sub runtime_options {
    my $self = shift;
    if ($self->is_win32) {
        return (
            '-ssh',
            ($self->connect_options->has_username
                ? ($self->connect_options->username . '@') : '')
                . $self->connect_options->host,
        );
    }
    else {
        return (
            ($self->connect_options->shkc ? () : ('-o', 'StrictHostKeyChecking=no')),
            @{$self->connect_options->opts},
            ($self->connect_options->has_username
                ? ('-l', $self->connect_options->username) : ()),
            $self->connect_options->host,
        );
    }
}

1;

# ABSTRACT: SSH based CLI connection


__END__
=pod

=head1 NAME

Net::CLI::Interact::Transport::SSH - SSH based CLI connection

=head1 VERSION

version 1.112610

=head1 DECRIPTION

This module provides a wrapped instance of an SSH client for use by
L<Net::CLI::Interact>.

=head1 INTERFACE

=head2 app

On Windows platforms you B<must> download the C<plink.exe> program, and pass its
location to the library in this parameter. On other platforms, this defaults to
C<ssh> (openssh).

=head2 runtime_options

Based on the C<connect_options> hash provided to Net::CLI::Interact on
construction, selects and formats parameters to provide to C<app> on the
command line. Supported attributes:

=over 4

=item host (required)

Host name or IP address of the host to which the SSH application is to
connect. Alternatively you can pass a value of the form C<user@host>, but it's
probably better to use the separate C<username> parameter instead.

=item username

Optionally pass in the username for the SSH connection, otherwise the SSH
client defaults to the current user's username. When using this option, you
should obviously I<only> pass the host name to C<host>.

=item shkc

Set to a false value to disable C<openssh>'s Strict Host Key Checking. See the
openssh documentation for further details. This might be useful where you are
connecting to appliances for which an entry does not yet exist in your
C<known_hosts> file, and you don't wish to be prompted to add it.

The default operation is to let openssh use its default setting for
StrictHostKeyChecking.

=item opts

If you want to pass any other options to openssh on its command line, then use
this option, which should be an array reference. Each item in the list will be
passed to C<openssh>, separated by a single space character. For example:

 $s->new({
     # ...other parameters to new()...
     connect_options => {
         opts => [
             '-p', '222',            # connect to non-standard port on remote host
             '-o', 'CheckHostIP=no', # don't check host IP in known_hosts file
         ],
     },
 });

=item reap

Only used on Unix platforms, this installs a signal handler which attempts to
reap the C<ssh> child process. Pass a true value to enable this feature only
if you notice zombie processes are being left behind after use.

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

This software is copyright (c) 2011 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

