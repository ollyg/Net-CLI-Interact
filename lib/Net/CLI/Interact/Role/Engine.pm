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
    my $resp = $self->last_actionset->item_at(-2)->response;
    return (wantarray
        ? (split $self->transport->irs, $resp)
        : $resp);
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
    my ($self, $name, $options) = @_;
    $options ||= {};

    my $params = ($options->{params} || []);
    $self->logger->log('engine', 'notice', 'running macro', $name);
    $self->logger->log('engine', 'info', 'macro params are:', join ', ', @$params);

    my $set = $self->phrasebook->macro->{$name}->clone;
    $set->apply_params(@$params);

    return $self->_execute_actions(
        $set,
        {timeout => $options->{timeout}}
    );

}

sub cmd {
    my ($self, $command, $options) = @_;
    $options ||= {};

    $self->logger->log('engine', 'notice', 'running command', $command);

    return $self->_execute_actions(
        Net::CLI::Interact::Action->new({
            type => 'send',
            value => $command,
            no_ors => $options->{no_ors},
        }),
        {timeout => $options->{timeout}}
    );
}

sub _execute_actions {
    my ($self, $options) = @_;
    $options ||= {};

    $self->logger->log('engine', 'notice', 'executing actions');

    # make connection on transport if not yet done
    $self->transport->connect if not $self->transport->done_connect;

    # user can install a prompt, call find_prompt, or let us trigger that
    $self->find_prompt if not ($self->prompt || $self->last_actionset);

    my $set = Net::CLI::Interact::ActionSet->new({
        actions => [@_],
        current_match => ($self->prompt || $self->last_prompt_as_match),
        default_continuation => $self->default_continuation,
    });
    $set->register_callback(sub { $self->transport->do_action(@_) });

    $self->logger->log('engine', 'debug', 'dispatching to execute method');
    my $timeout_bak = $self->transport->timeout;

    $self->transport->timeout($options->{timeout} || $timeout_bak);
    $set->execute;
    $self->transport->timeout($timeout_bak);
    $self->last_actionset($set);

    # if user used a match ref then we assume new prompt value
    if ($self->last_actionset->last->is_lazy) {
        $self->logger->log('prompt', 'info',
            'last match was a prompt reference, setting new prompt');
        $self->_prompt($self->last_actionset->last->value);
    }

    return $self->last_response; # context sensitive
}

1;

# ABSTRACT: Statement execution engine

=head1 DESCRIPTION

This module is the core of L<Net::CLI::Interact>, and serves to take entries
from your loaded L<Phrasebooks|Net::CLI::Interact::Phrasebook>, issue them to
connected devices, and gather the returned output.

=head1 INTERFACE

=head2 cmd($command_statement, \%options?)

Execute a single command statement on the connected device, and consume output
until there is a match with the current I<prompt>. The statement is executed
verbatim on the device, with a newline appended.

The following options are supported:

=over 4

=item C<< timeout => $seconds >> (optional)

Sets a value of C<timeout> for the L<Transport|Net::CLI::Interact::Transport>
local to this call of C<cmd>, that overrides whatever is set in the Transport,
or the default of 10 seconds.

=item C<< no_ors => 1 >> (optional)

When passed a true value, a newline character (in fact the value of C<ors>)
will not be appended to the statement sent to the device.

=back

In scalar context the C<last_response> is returned (see below). In list
context the gathered response is returned, only split into a list on the
I<input record separator> (newline).

=head2 macro($macro_name, \%options?)

Execute the commands contained within the named Macro, which must be loaded
from a Phrasebook. Options to control the output, including variables for
substitution into the Macro, are passed in the C<%options> hash reference.

The following options are supported:

=over 4

=item C<< params => \@values >> (optional)

If the Macro contains commands using C<sprintf> Format variables then the
corresponding parameters must be passed in this value as an array reference.

Values are consumed from the provided array reference and passed to the
C<send> commands in the Macro in order, as needed. An exception will be thrown
if there are insufficient parameters.

=item C<< timeout => $seconds >> (optional)

Sets a value of C<timeout> for the L<Transport|Net::CLI::Interact::Transport>
local to this call of C<macro>, that overrides whatever is set in the
Transport, or the default of 10 seconds.

=back

An exception will be thrown if the Match statements in the Macro are not
successful against the output returned from the device. This is based on the
value of C<timeout>, which controls how long the module waits for matching
output.

In scalar context the C<last_response> is returned (see below). In list
context the gathered response is returned, only split into a list on the
I<input record separator> (newline).

=head2 last_response

Returns the gathered output after issueing the last recent C<send> command
within the most recent C<cmd> or C<prompt>. That is, you get the output from
the last command sent to the connected device.

In scalar context all data is returned. In list context the gathered response
is returned, only split into a list on the I<input record separator>
(newline).

=head2 last_actionset

Returns the complete L<ActionSet|Net::CLI::Interact::ActionSet> that was
constructed from the most recent C<macro> or C<cmd> execution. This will be a
sequence of L<Actions|Net::CLI::Interact::Action> that correspond to C<send>
and C<match> statements.

In the case of a Macro these directly relate to the contents of your
Phrasebook, with the possible addition of C<match> statements added
automatically. In the case of a C<cmd> execution, an "anonymous" Macro is
constructed which consists of a single C<send> and a single C<match>.

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Role::Prompt>

=back

=cut
