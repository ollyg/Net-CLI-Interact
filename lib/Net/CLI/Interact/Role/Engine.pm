package Net::CLI::Interact::Role::Engine;

use Moose::Role;
with 'Net::CLI::Interact::Role::Prompt';

use Net::CLI::Interact::Action;
use Net::CLI::Interact::ActionSet;

has 'last_actionset' => (
    is => 'rw',
    isa => 'Net::CLI::Interact::ActionSet',
    required => 0,
);

sub last_response {
    my $self = shift;
    return $self->last_actionset->item_at(-2)->response;
}

has 'default_continuation' => (
    is => 'rw',
    isa => 'Net::CLI::Interact::ActionSet',
    writer => '_default_continuation',
    clearer => 'clear_default_continuation',
    required => 0,
);

sub set_default_continuation {
    my ($self, $cont) = @_;
    confess "missing continuation" unless $cont;
    confess "unknown continuation [$cont]" unless
        exists $self->phrasebook->macro->{$cont};
    $self->_default_continuation( $self->phrasebook->macro->{$cont} );
    $self->logger->log('engine', 'info', 'default continuation set to', $cont);
}

sub macro {
    my ($self, $name, @params) = @_;
    $self->logger->log('engine', 'notice', 'running macro', $name);
    $self->logger->log('engine', 'info', 'macro params are:', join ', ', @params);

    my $set = $self->phrasebook->macro->{$name}->clone;
    $set->apply_params(@params);
    $self->_execute_actions($set);
}

sub cmd {
    my ($self, $command) = @_;
    $self->logger->log('engine', 'notice', 'running command', $command);

    $self->_execute_actions(
        Net::CLI::Interact::Action->new({
            type => 'send',
            value => $command,
        }),
    );
}

sub _execute_actions {
    my $self = shift;
    $self->logger->log('engine', 'notice', 'executing actions');

    # make connection on transport if not yet done
    $self->transport->connect if not $self->transport->done_connect;

    # user can install a prompt, call find_prompt, or let us trigger that
    $self->find_prompt if not $self->last_actionset;

    my $set = Net::CLI::Interact::ActionSet->new({
        actions => [@_],
        current_match => ($self->prompt || $self->last_prompt_as_match),
        default_continuation => $self->default_continuation,
    });
    $set->register_callback(sub { $self->transport->do_action(@_) });

    $self->logger->log('engine', 'debug', 'dispatching to execute method');
    $set->execute;
    $self->last_actionset($set);

    # if user used a match ref then we assume new prompt value
    if ($self->last_actionset->last->is_lazy) {
        $self->logger->log('prompt', 'info', 'last match was a prompt reference, setting new prompt');
        $self->_prompt($self->last_actionset->last->value);
    }

    return (wantarray
        ? (split $self->transport->irs, $self->last_response)
        : $self->last_response);
}

1;

# ABSTRACT: Command statement execution and Prompt management

=head1 SYNOPSIS

 $s->set_prompt('user_exec');
 
 $s->macro('show_int_br');
 my $interfaces = $s->last_response;
 
 $s->cmd('show ip interfaces brief');
 my $same_as_interfaces = $s->last_response;
 
 $s->macro('to_priv_exec', 'enable_password');
 # prompt is updated automatically
 
 $s->macro('show_run');
 my $config = $s->last_response;

=head1 DESCRIPTION

This module implements the API for command execution and Prompt management in
L<Net::CLI::Interact>. After the Phrasebooks are loaded, a table of Prompts
and a table of Macros is available to the application.

=head1 METHODS

=over 4

=item prompt

Returns the current Prompt, which is a regular expression reference. The
Prompt is used as a default when a Macro has not been set up with explicit
Prompt matching.

Typically you would set the prompt you are expecting (see below) once for a
sequence of commands in a particular CLI context. The C<prompt> is also
automatically updated when a Macro successfully ends which was defined in the
Phrasebook with a known Prompt (referenced by name using C<match prompt...>).

=item unset_prompt

You can use this method to empty the current Prompt setting (see above). The
effect is that the module will automatically set the Prompt for itself based
on the last line of output received from the connected CLI. Do not use this
option unless you know what you are doing.

=item set_prompt($prompt_name)

This method will be used most commonly by applications to set a prompt from
the Phrasebook which matches the current context of the connected CLI session.
This allows a sequence of commands to be sent which share the same Prompt.

=item find_prompt

A helper method that consumes output from the connected CLI session until a
line matches one of the named Prompts in the loaded Phrasebooks, at which
point no more output is consumed. As a consequence the C<prompt> will be set
(see above) and also the C<last_*> (see below) accessors.

This might be used when you are connecting to a device which maintains CLI
state between sessions (for example a serial console), and you need to
discover the current state. However, C<find_prompt> is executed automatically
for you if you call a C<cmd> or C<macro> before any interaction with the CLI.

You might need to send some input to the device to trigger generation of
output for matching. If no output matches, the module will time out and throw
an exception (see C<timeout>, documented elsewhere), in which case no output
will be consumed so you are free to attempt another C<find_prompt>.

=item macro($macro_name, ?@params)

Execute the commands contained within the named Macro, which must be loaded
in a Phrasebook. If the Macro contains commands using C<sprintf> Format
variables then the corresponding parameters must be passed to the method.

Values are consumed from the provided C<@params> and passed to the C<send>
commands in the Macro in order, as needed. An exception will be thrown if
there are insufficient parameters.

An exception will also be thrown if the Match statements in the Macro are not
successful with the output returned from the device. This is based on the
value C<timeout>, which controls how long the module waits for matching
output.

=item cmd($command_statement)

Execute a single C<send> command statement and consume output until there is a
match with the current value of C<prompt>. The statement is executed verbatim
on the device, with a newline appended.

=item last_response

Returns the gathered output after issueing the most recent C<send> command.

=item last_prompt

Returns the Prompt which most recently was matched to terminate gathering of
output from the connected CLI. This is a simple text string.

=item last_prompt_as_match

Returns the text which was most recently matched to terminate gathering of
output from the connected CLI, as a regular expression with line start and end
anchors.

=item last_actionset

Returns the complete L<Net::CLI::Interact::ActionSet> that was constructed
from the most recent C<macro> or C<cmd> execution. This will be a sequence of
Actions that correspond to C<send> and C<match> statements.

In the case of a Macro these directly relate to the contents of your
Phrasebook, with the possible addition of C<match> statements added
automatically. In the case of a C<cmd> execution, in effect a Macro is
constructed which consists of a single C<send> and a single C<match>.

=back

