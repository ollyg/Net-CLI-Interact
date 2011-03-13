package Net::CLI::Interact;

use Moose;
with 'Net::CLI::Interact::Role::Engine';

has params => (
    is => 'ro',
    isa => 'HashRef[Any]',
    auto_deref => 1,
    required => 1,
);

sub BUILDARGS {
    my ($class, @params) = @_;
    return { params => { @params } };
}

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    lazy_build => 1,
);

sub _build_logger {
    my $self = shift;
    use Net::CLI::Interact::Logger;
    return Net::CLI::Interact::Logger->new({$self->params});
}

has 'phrasebook' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Phrasebook',
    lazy_build => 1,
);

sub _build_phrasebook {
    my $self = shift;
    use Net::CLI::Interact::Phrasebook;
    return Net::CLI::Interact::Phrasebook->new({
        logger => $self->logger,
        $self->params,
    });
}

has 'transport' => (
    is => 'ro',
    does => 'Net::CLI::Interact::Role::Transport',
    lazy_build => 1,
);

sub _build_transport {
    my $self = shift;
    my $tpt = 'Net::CLI::Interact::Transport::'. $self->params->{transport};
    use Class::MOP;
    Class::MOP::load_class($tpt);
    return $tpt->new({
        logger => $self->logger,
        $self->params,
    });
}

1;

# ABSTRACT: Toolkit for CLI Automation

=head1 PURPOSE

This module exists to support developers of applications and libraries which
must interact with a command line interface.

=head1 SYNOPSIS

 use Net::CLI::Interact;
 
 my $s = Net::CLI::Interact->new({
    personality => 'cisco',
    transport   => 'Telnet',
    transport_options => { host => '192.0.2.1' },
 });
 
 # respond to a usename/password prompt
 $s->macro('to_user_exec', 'my_username', 'my_password');
 
 my $interfaces = $s->cmd('show ip interfaces brief');
 
 $s->macro('to_priv_exec', 'my_password');
 # matched prompt is updated automatically
 
 # paged output is slurped into one response
 $s->macro('show_run');
 my $config = $s->last_response;

=head1 DESCRIPTION

Automating command line interface (CLI) interactions is not a new idea, but
can be tricky to implement. This module aims to provide a simple and
manageable interface to CLI interactions, supporting:

=over 4

=item *

SSH, Telnet and Serial-Line connections

=item *

Unix and Windows support

=item *

Reuseable device command phrasebooks

=back

=head1 METHODS

=head2 new( \%options )

Prepares a new session for you, but will not connect to any device. Options
are:

=over 4

=item C<< personality => $name >> (required)

The family of device command phrasebooks to load. There is a built-in library
within this module, or you can provide a search path to other libraries. See
L<Net::CLI::Interact::Phrasebook> for further details.

=item C<< transport => $backend >> (required)

The name of the transport backend used for the session, which may be one of
L<Telnet|Net::CLI::Interact::Telnet>, L<SSH|Net::CLI::Interact::SSH>, or
L<Serial|Net::CLI::Interact::Serial>.

=item C<< transport_options => \%options >>

If the transport backend can take any options (for example the target
hostname), then pass those options in this value. See the respective manual
pages for each transport backend for further details.

=back

=head2 cmd( $command )

Execute a single command statement on the connected device, and consume output
until there is a match with the current I<prompt>. The statement is executed
verbatim on the device, with a newline appended.

In scalar context the C<last_response> is returned; in list context it is
returned but split into a list on the I<input record separator> (newline).

=head2 macro( $name, \@params? )

Execute the commands contained within the named Macro, which must be available
in the loaded Phrasebook. If the Macro contains commands using C<sprintf>
format variables then the corresponding total number of C<@params> must be
passed to the method.

In scalar context the C<last_response> is returned; in list context it is
returned but split into a list on the I<input record separator> (newline).

=head2 last_response

Returns the gathered output after the most recent C<cmd> or C<macro>.

=head2 phrasebook

Returns the Phrasebook object which was loaded based on the C<personality>
option given to C<new>. See L<Net::CLI::Interact::Phrasebook> for further
details.

=head2 transport

Returns the L<Transport|Net::CLI::Interact::Role::Transport> backend which was
loaded based on the C<transport> option to C<new>. See the
L<Telnet|Net::CLI::Interact::Telnet>, L<SSH|Net::CLI::Interact::SSH>, or
L<Serial|Net::CLI::Interact::Serial> documentation for further details.

=head2 logger

This is the application's L<Logger|Net::CLI::Interact::Logger> object. A
powerful logging subsystem is available to your application, built upon the
L<Log::Dispatch> distribution. You can enable logging of this module's
processes at various levels, or add your own logging statements.

=head1 FUTHER READING

=head2 Prompt Matching

Whenever a command statement is issued, output is slurped until a matching
prompt is seen in that output. Control of the Prompts is shared between the
definitions in L<Net::CLI::Interact::Phrasebook> dictionaries, and methods of
the L<Net::CLI::Interact::Role::Prompt> core component. See that module's
documentation for further details.

=head2 Actions and ActionSets

All commands and macros are composed from their phrasebook definitions into
L<Actions|Net::CLI::Interact::Action> and
L<ActionSets|Net::CLI::Interact::ActionSet> (simply iterable sequences of
Actions). See those modules' documentation for further details, in case you
wish to introspect their structures.

=cut
