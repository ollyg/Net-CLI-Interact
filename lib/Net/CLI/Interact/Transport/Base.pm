package Net::CLI::Interact::Transport::Base;

use Moose;
use Moose::Util::TypeConstraints;

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    required => 1,
);

has 'irs' => (
    is => 'ro',
    isa => 'Str',
    default => "\n",
    required => 0,
);

sub irs_re {
    my $self = shift;
    my $irs = $self->irs;
    return qr/$irs/;
}

has 'ors' => (
    is => 'ro',
    isa => 'Str',
    default => "\n",
    required => 0,
);

has 'timeout' => (
    is => 'rw',
    isa => subtype( 'Int' => where { $_ > 0 } ),
    required => 0,
    default => 10,
);

has 'app' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has 'stash' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    required => 0,
);

has 'wrapper' => (
    is => 'rw',
    isa => 'Object',
    lazy_build => 1,
    required => 0,
    predicate => 'connect_ready',
);

sub _build_wrapper {
    my $self = shift;
    $self->logger->log('transport', 'debug', 'command expands to: ',
        $self->app, (join ' ', map {($_ =~ m/\s/) ? ("'". $_ ."'") : $_}
                                   $self->runtime_options));
    # this better be wrapped otherwise it'll blow up
};

sub go { (shift)->wrapper(@_) }

sub flush {
    my $self = shift;
    my $content = $self->stash . $self->buffer;
    $self->stash('');
    $self->buffer('');
    return $content;
}

sub disconnect {
    my $self = shift;
    $self->clear_wrapper;
    $self->flush;
    1;
}

sub _abc { confess "not implemented." }

sub put { _abc() }
sub pump { _abc() }
sub buffer { _abc() }

sub DEMOLISH { (shift)->disconnect }

# see if any regexp in the arrayref match the response
sub _first_match {
    my ($text, $matches) = @_;
    $matches = ((ref $matches eq ref qr//) ? [$matches] : $matches);
    return undef unless
        (scalar grep {ref $_ eq ref qr//} @$matches) == scalar @$matches;

    use List::Util 'first';
    return first { $text =~ $_ } @$matches;
}

sub do_action {
    my ($self, $action) = @_;
    $self->logger->log('transport', 'info', 'callback received for', $action->type);

    if ($action->type eq 'match') {
        my $cont = $action->continuation;
        while ($self->pump) {
            $self->logger->log('dump', 'debug', "SEEN:\n". $self->buffer);

            my @out_lines = split $self->irs_re, $self->buffer;
            next if !defined $out_lines[-1];

            my $maybe_stash = join $self->irs, @out_lines[0 .. ($#out_lines - 1)];
            my $last_out = $out_lines[-1];

            if ($cont and $last_out =~ $cont->first->value) {
                $self->logger->log('transport', 'debug', 'continuation matched');
                $self->stash($self->flush);
                $self->put($cont->last->value);
            }
            elsif (my $hit = _first_match($last_out, $action->value)) {
                $self->logger->log('transport', 'debug',
                    sprintf 'output matched %s, storing and returning', $hit);
                # prompt match is line oriented. want to split that off from
                # rest of output which is marshalled into the 'send'.
                my @output = split $self->irs_re, $self->flush;
                $action->response_stash(join $self->irs, @output[0 .. ($#output - 1)]);
                $action->response($output[-1]);
                last;
            }
            else {
                $self->logger->log('transport', 'debug', "nope, doesn't (yet) match", $action->value);
                # put back the partial output and try again
                $self->stash( $self->stash . $maybe_stash );
                $self->buffer($last_out);
            }
        }
    }
    if ($action->type eq 'send') {
        my $command = sprintf $action->value, $action->params;
        $self->logger->log('transport', 'debug', 'queueing data for send: "'. $command .'"');
        $self->put( $command . ($action->no_ors ? () : $self->ors) );
    }
}
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

