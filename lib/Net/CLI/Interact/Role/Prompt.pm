package Net::CLI::Interact::Role::Prompt;

use Moose::Role;
use Net::CLI::Interact::ActionSet;

has 'wake_up' => (
    is => 'rw',
    isa => 'Str',
    default => sub { (shift)->transport->ors },
    predicate => 'has_wake_up',
    required => 0,
);

has '_prompt' => (
    is => 'rw',
    isa => 'Maybe[RegexpRef]',
    required => 0,
    reader => 'prompt_re',
    clearer => 'unset_prompt',
    trigger => sub {
        (shift)->logger->log('prompt', 'info', 'prompt has been set to', (shift));
    },
);

sub set_prompt {
    my ($self, $prompt) = @_;
    confess "unknown prompt: [$prompt]"
        unless eval { $self->phrasebook->prompt($prompt) };
    $self->_prompt( $self->phrasebook->prompt($prompt)->first->value );
}

sub last_prompt {
    my $self = shift;
    return $self->last_actionset->item_at(-1)->response;
}

sub last_prompt_as_match {
    my $prompt = (shift)->last_prompt;
    return qr/^\Q$prompt\E$/;
}

# pump until any of the prompts matches the output buffer
sub find_prompt {
    my ($self, $tries) = @_;
    $self->logger->log('prompt', 'notice', 'finding prompt');

    # make connection on transport if not yet done
    $self->transport->connect if not $self->transport->done_connect;

    eval {
        while ($self->transport->harness->pump) {
            foreach my $prompt (keys %{ $self->phrasebook->prompt }) {
                # prompts consist of only one match action
                if ($self->transport->out =~ $self->phrasebook->prompt($prompt)->first->value) {
                    $self->logger->log('prompt', 'info', "hit, matches prompt $prompt");
                    $self->last_actionset(
                        Net::CLI::Interact::ActionSet->new({ actions => [
                            $self->phrasebook->prompt($prompt)->first->clone({
                                response => $self->transport->flush,
                            })
                        ] })
                    );
                    $self->set_prompt($prompt);
                    return;
                }
                $self->logger->log('prompt', 'debug', "nope, doesn't (yet) match $prompt");
            }
        }
    };
    # default call from user, $tries is zero, so run once more and inc tries
    if ($@ and $self->has_wake_up and $tries) {
        $self->logger->log('prompt', 'info', 'timeout, sending WAKE_UP and trying again');
        $self->transport->send( $self->wake_up );
        $self->find_prompt;
    }
}

1;

# ABSTRACT: Command-line prompt management

=head1 DESCRIPTION

This is another core component of L<Net::CLI::Interact>, and its role is to
keep track of the current prompt on the connected command line interface. The
idea is that most CLI have a prompt where you issue commands, and are returned
some output which this module gathers. The prompt is a demarcation between
each command and its response data.

=head1 INTERFACE

=head2 set_prompt( $prompt_name )

This method will be used most commonly by applications to select and set a
prompt from the Phrasebook which matches the current context of the connected
CLI session. This allows a sequence of commands to be sent which share the
same Prompt.

The name you pass in is looked up in the loaded Phrasebook and the entry's
regular expression stored in the C<prompt> slot. An exception is thrown if the
named Prompt is not known.

Typically you would either refer to a Prompt in a Macro, or set the prompt you
are expecting once for a sequence of commands in a particular CLI context.

When a Macro completes and it has been defined in the Phrasebook with an
explicit named Prompt at the end, we can assume the user is indicating some
change of context. Therefore the C<prompt> is I<automatically updated> on such
occasions to have the regular expression from that named Prompt.

=head2 prompt

Returns the current Prompt, which is a regular expression reference. The
Prompt is used as a default to catch the end of command response output, when
a Macro has not been set up with explicit Prompt matching.

Typically you would either refer to a Prompt in a Macro, or set the prompt you
are expecting once for a sequence of commands in a particular CLI context.

=head2 unset_prompt

Use this method to empty the current C<prompt> setting (see above). The effect
is that the module will automatically set the Prompt for itself based on the
last line of output received from the connected CLI. Do not use this option
unless you know what you are doing.

=head2 find_prompt( $wake_up? )

A helper method that consumes output from the connected CLI session until a
line matches one of the named Prompts in the loaded Phrasebooks, at which
point no more output is consumed. As a consequence the C<prompt> will be set
(see above).

This might be used when you're connecting to a device which maintains CLI
state between session disconnects (for example a serial console), and you need
to discover the current state. However, C<find_prompt> is executed
automatically for you if you call a C<cmd> or C<macro> before any interaction
with the CLI.

The current device output will be scanned against all known named Prompts. If
nothing is found, the default behaviour is then to send the content of our
C<wake_up> slot (see below), and try to match again. The idea is that by
sending one carriage return, we might be sent a new prompt. If you wish to
disable this behaviour, pass a I<false> value into this method.

=head2 wake_up

Data sent to a device within C<find_prompt> if no output has so far matched
any known named Prompt. Default is the value of the I<output record separator>
from the L<Transport|Net::CLI::Interact::Transport> (newline).

=head2 last_prompt

Returns the Prompt which most recently was matched and terminated gathering of
output from the connected CLI. This is a simple text string.

=head2 last_prompt_as_match

Returns the text which was most recently matched and terminated gathering of
output from the connected CLI, as a quote-escaped regular expression with line
start and end anchors.

=cut
