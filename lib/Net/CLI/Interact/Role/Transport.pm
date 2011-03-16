package Net::CLI::Interact::Role::Transport;

use Moose::Role;
use IPC::Run ();

use Moose::Util::TypeConstraints;
subtype 'Net::CLI::Interact::Types::Transport::irs'
    => as 'RegexpRef';
coerce 'Net::CLI::Interact::Types::Transport::irs'
    => from 'Str'
        => via { m/$_/ };

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    required => 1,
);

has 'transport_options' => (
    is => 'ro',
    isa => 'HashRef[Any]',
    required => 1,
    default => sub { {} },
);

has 'irs' => (
    is => 'ro',
    coerce => 1,
    isa => 'Net::CLI::Interact::Types::Transport::irs',
    default => sub { qr/\n/ },
    required => 0,
);

has 'ors' => (
    is => 'ro',
    isa => 'Str',
    default => sub { "\n" },
    required => 0,
);

has '_in' => (
    is => 'rw',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

# writer for the _in slot
sub send { ${ (shift)->_in } .= join '', @_ }

has '_out' => (
    is => 'ro',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

# mutator for the _out slot
sub out {
    my $self = shift;
    return ${ $self->_out } if scalar(@_) == 0;
    return ${ $self->_out } = shift;
}

has '_stash' => (
    is => 'rw',
    isa => 'Str',
    default => sub { '' },
    required => 0,
);

# clearer for the _out slot
sub flush {
    my $self = shift;
    my $content = $self->_stash . $self->out;
    $self->_stash('');
    ${ $self->_out } = '';
    return $content;
}

has '_err' => (
    is => 'ro',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

has 'harness' => (
    is => 'rw',
    isa => 'IPC::Run',
    required => 0,
    predicate => 'done_connect',
);

has '_timeout_obj' => (
    is => 'ro',
    isa => 'IPC::Run::Timer',
    lazy_build => 1,
    required => 0,
);

sub _build__timeout_obj { return IPC::Run::timeout((shift)->timeout) }

has 'timeout' => (
    is => 'rw',
    isa => 'Int',
    required => 0,
    default => 10,
    trigger => sub {
        (shift)->_timeout_obj->start(shift) if scalar @_ > 1;
    },
);

sub connect {
    my $self = shift;
    $self->logger->log('transport', 'notice', 'booting IPC::Run harness for', $self->app);

    $self->harness(
        IPC::Run::harness(
            [$self->app, $self->runtime_options],
               $self->_in,
               $self->_out,
               $self->_err,
               $self->_timeout_obj,
        )
    );
}

# returns either the content of the output buffer, or undef
sub do_action {
    my ($self, $action) = @_;
    $self->logger->log('transport', 'info', 'callback received for', $action->type);

    if ($action->type eq 'match') {
        my $cont = $action->continuation;
        while ($self->harness->pump) {
            my $irs = $self->irs;
            my @out_lines = split m/$irs/, $self->out;
            my $maybe_stash = join $self->irs, @out_lines[0 .. -2];
            my $last_out = $out_lines[-1];

            if ($cont and $last_out =~ $cont->first->value) {
                $self->logger->log('transport', 'debug', 'continuation matched');
                $self->_stash($self->flush);
                $self->send($cont->last->value);
            }
            elsif ($last_out =~ $action->value) {
                $self->logger->log('transport', 'debug',
                    sprintf 'output matched %s, storing and returning', $action->value);
                $action->response($self->flush);
                last;
            }
            else {
                $self->logger->log('transport', 'debug', "nope, doesn't (yet) match", $action->value);
                # put back the partial output and try again
                $self->_stash( $self->_stash . $maybe_stash );
                $self->out($last_out);
            }
        }
    }
    if ($action->type eq 'send') {
        my $command = sprintf $action->value, $action->params;
        $self->logger->log('transport', 'debug', 'queueing data for send:', $command);
        $self->send( $command, ($action->no_ors ? () : $self->ors) );
    }
}

1;

# ABSTRACT: Wrapper for IPC::Run for a CLI

=head1 DESCRIPTION

This module provides a wrapped interface to L<IPC::Run> for the purpose of
interacting with a command line interface. Given an application path, the
program will be started and an interface is provided to send commands and
slurp the response output.

You should not use this role directly, but instead consume it within a
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

=head2 do_action

When passed a L<Net::CLI::Interact::Action> instance, will execute the
contained instruction on the connected CLI. This might be a command to
C<send>, or a regular expression to C<match> in the output.

Features of the commands and prompts are supported, such as Continuation
matching (and slurping), and sending without an I<output record separator>.

On failing to succeed with a Match, the module will time-out (see C<timeout>,
below) and raise an exception.

Output returned after issueing a command is stored within the Match Action's
C<response> slot by this method, but then marshalled into the correct C<send>
Action by the L<ActionSet|Net::CLI::Interact::ActionSet>.

=head2 send(@data)

Buffer for C<@data> which is to be sent to the connected CLI. Items in the
list are joined together by an empty string.

=head2 out

Buffer for response data returned from the connected CLI. You can check the
content of the buffer without emptying it.

=head2 flush

Empties the buffer used for response data returned from the connected CLI, and
returns that data as a single text string (possibly with embedded newlines).

=head2 timeout($seconds?)

When C<do_action> is polling C<out> for response data matching a regular
expression Action, it will eventually time-out and throw an exception if
nothing matches and no more data arrives.

The number of seconds to wait is set via this method, which will also return
the current value of C<timeout>.

=head2 irs

Line separator character(s) used when interpreting the data returned from the
connected CLI. This defaults to a newline on the application's platform.

=head2 ors

Line separator character(s) appended to a command sent to the connected CLI.
This defaults to a newline on the application's platform.

=head2 harness

Slot for storing the L<IPC::Run> instance for the connected transport session.
Do not mess with this unless you know what you are doing.

=head2 transport_options

Slot for storing a Hash Ref of options for the specific loaded Transport,
passed by the user of C<Net::CLI::Interact>. Do not access this directly, but
instead use C<runtime_options> from the specific Transport class.

=head2 logger

Slot for storing a reference to the application's
L<Logger|Net::CLI::Interact::Logger> object.

=cut

