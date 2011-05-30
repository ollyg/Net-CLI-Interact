package Net::CLI::Interact::Transport::Base::Win32;

use Moose;
use Moose::Util::TypeConstraints;

extends 'Net::CLI::Interact::Transport::Base';

{
    package # hide from pause
        Net::CLI::Interact::Transport::Platform::Options;
    use Moose;
    extends 'Net::CLI::Interact::Transport::Base::Options';
}

use IPC::Run ();

has '_in' => (
    is => 'rw',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

# writer for the _in slot
sub put { ${ (shift)->_in } .= join '', @_ }

has '_out' => (
    is => 'ro',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

sub buffer {
    my $self = shift;
    return ${ $self->_out } if scalar(@_) == 0;
    return ${ $self->_out } = shift;
}

# clearer for the _out slot
has '_err' => (
    is => 'ro',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

has '_timeout_obj' => (
    is => 'ro',
    isa => 'IPC::Run::Timer',
    lazy_build => 1,
    required => 0,
);

sub _build__timeout_obj { return IPC::Run::timeout((shift)->timeout) }

has '+timeout' => (
    trigger => sub {
        (shift)->_timeout_obj->start(shift) if scalar @_ > 1;
    },
);

has '+wrapper' => (
    isa => 'IPC::Run',
    handles => ['pump'],
);

override '_build_wrapper' => sub {
    my $self = shift;

    $self->logger->log('transport', 'notice', 'booting IPC::Run harness for', $self->app);
    super();

    return IPC::Run::harness(
        [$self->app, $self->runtime_options],
            $self->_in,
            $self->_out,
            $self->_err,
            $self->_timeout_obj,
    );
};

before 'disconnect' => sub {
    my $self = shift;
    $self->wrapper->kill_kill(grace => 1);
};

1;

# ABSTRACT: Wrapper for IPC::Run for a CLI

=head1 DESCRIPTION

This module provides a wrapped interface to L<IPC::Run> for the purpose of
interacting with a command line interface. Given an application path, the
program will be started and an interface is provided to send commands and
slurp the response output.

You should not use this class directly, but instead inherit from it in
specific Transport that will set the application command line name, and
marshall any runtime options.

=head1 INTERFACE

=head2 connect

This method I<must> be called before any other, to establish the L<IPC::Run>
infrastructure. However via L<Net::CLI::Interact>'s C<cmd>, C<match> or
C<find_prompt> it will be called for you automatically.

Two attributes of the specific loaded Transport are used. First the
Application set in C<app> is of course required, plus the options in the
Transport's C<runtime_options> are retrieved, if set, and passed as command
line arguments to the Application.

=head2 done_connect

Returns True if C<connect> has been called successfully, otherwise returns
False.

=head2 disconnect

Undefines the IPC::Run harness and flushes any output data buffer such that
the next call to C<cmd> or C<macro> will cause a new connection to be made.
Useful if you intentionally timeout a command and end up with junk in the
output buffer.

=head2 do_action

When passed a L<Net::CLI::Interact::Action> instance, will execute the
contained instruction on the connected CLI. This might be a command to
C<send>, or a regular expression to C<match> in the output.

Features of the commands and prompts are supported, such as Continuation
matching (and slurping), and sending without an I<output record separator>.

On failing to succeed with a Match, the module will time-out (see C<timeout>,
below) and raise an exception.

Output returned after issueing a command is stored within the Match Action's
C<response> and C<response_stash> slots by this method, with the latter then
marshalled into the correct C<send> Action by the
L<ActionSet|Net::CLI::Interact::ActionSet>.

=head2 send( @data )

Buffer for C<@data> which is to be sent to the connected CLI. Items in the
list are joined together by an empty string.

=head2 out

Buffer for response data returned from the connected CLI. You can check the
content of the buffer without emptying it.

=head2 flush

Empties the buffer used for response data returned from the connected CLI, and
returns that data as a single text string (possibly with embedded newlines).

=head2 timeout( $seconds? )

When C<do_action> is polling C<out> for response data matching a regular
expression Action, it will eventually time-out and throw an exception if
nothing matches and no more data arrives.

The number of seconds to wait is set via this method, which will also return
the current value of C<timeout>.

=head2 irs

Line separator character(s) used when interpreting the data returned from the
connected CLI. This defaults to a newline on the application's platform.

=head2 irs_re

Returns a Regular Expression reference comprising the content of C<irs>. With
the default value, this will be C<< qr/\n/ >>. This is useful if you need to
C<split> the content of your Action's C<response> into lines.

=head2 ors

Line separator character(s) appended to a command sent to the connected CLI.
This defaults to a newline on the application's platform.

=head2 harness

Slot for storing the L<IPC::Run> instance for the connected transport session.
Do not mess with this unless you know what you are doing.

=head2 connect_options

Slot for storing a set of options for the specific loaded Transport, passed by
the user of Net::CLI::Interact as a hash ref. Do not access this directly, but
instead use C<runtime_options> from the specific Transport class.

=head2 logger

Slot for storing a reference to the application's
L<Logger|Net::CLI::Interact::Logger> object.

=head2 needs_pty

This is a hint to the Transport back-end that the spawned application requires
a controlling pseudo terminal. The canonical example of this is the OpenSSH
client. By default this has a False value but in the SSH Transport it's True.

=cut

