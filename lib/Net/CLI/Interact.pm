package Net::CLI::Interact;
BEGIN {
  $Net::CLI::Interact::VERSION = '1.112600';
}

{
    package # hide from pause
        Net::CLI::Interact::Meta::Attribute::Trait::Mediated;
    use Moose::Role;

    package # hide from pause
        Moose::Meta::Attribute::Custom::Trait::Mediated;
    sub register_implementation {
        return 'Net::CLI::Interact::Meta::Attribute::Trait::Mediated';
    }
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

use Moose;
with 'Net::CLI::Interact::Role::Engine';

has '__mediator_params' => (
    is => 'ro',
    isa => 'HashRef[Any]',
    auto_deref => 1,
    required => 1,
);

# takes the params hash and returns two hashes, the params
# hash and a new hash of the current class's attribute slots
sub _filter_my_attribute_list {
    my ($class, $params) = @_;
    my $our_params = {};
    my $meta = $class->meta;

    foreach my $slot (keys %$params) {
        my $attr = $class->meta->get_attribute($slot);

        if ($attr and
            not $attr->does('Net::CLI::Interact::Meta::Attribute::Trait::Mediated')) {

            $our_params->{$slot} = delete $params->{$slot};
        }
    }

    return $params, $our_params;
}

sub BUILDARGS {
    my ($class, @params) = @_;
    return { __mediator_params => {} } unless scalar @params > 0;
    my %stuff = ((scalar @params > 1) ? @params : %{$params[0]});

    my ($m_params, $our_params) = $class->_filter_my_attribute_list(\%stuff);

    return {
        __mediator_params => { %$m_params },
        %$our_params,
    };
}

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    lazy_build => 1,
    traits => ['Mediated'],
);

sub _build_logger {
    my $self = shift;
    use Net::CLI::Interact::Logger;
    return Net::CLI::Interact::Logger->new({$self->__mediator_params});
}

has 'log_at' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    required => 0,
    default => $ENV{'NCI_LOG_AT'},
    trigger => \&set_global_log_at,
);

sub set_global_log_at {
    my ($self, $level) = @_;
    return unless defined $level and length $level;
    $self->logger->log_flags({
        map {$_ => $level} qw/dump engine phrasebook prompt transport/
    });
}

sub BUILD { my $self = shift; $self->set_global_log_at($self->log_at); }

has 'phrasebook' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Phrasebook',
    lazy_build => 1,
    traits => ['Mediated'],
);

sub _build_phrasebook {
    my $self = shift;
    use Net::CLI::Interact::Phrasebook;
    return Net::CLI::Interact::Phrasebook->new({
        logger => $self->logger,
        $self->__mediator_params,
    });
}

# does not really *change* the phrasebook, just reconfig and nuke
sub set_phrasebook {
    my ($self, $args) = @_;
    return unless defined $args and ref $args eq ref {};
    foreach my $k (keys %$args) {
        $self->__mediator_params->{$k} = $args->{$k};
    }
    $self->clear_phrasebook;
}

has 'transport' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport',
    lazy_build => 1,
    traits => ['Mediated'],
);

sub _build_transport {
    my $self = shift;
    confess 'missing transport' unless exists $self->__mediator_params->{transport};
    my $tpt = 'Net::CLI::Interact::Transport::'. $self->__mediator_params->{transport};
    use Class::MOP;
    Class::MOP::load_class($tpt);
    return $tpt->new({
        logger => $self->logger,
        $self->__mediator_params,
    });
}

1;

# ABSTRACT: Toolkit for CLI Automation


__END__
=pod

=head1 NAME

Net::CLI::Interact - Toolkit for CLI Automation

=head1 VERSION

version 1.112600

=head1 PURPOSE

This module exists to support developers of applications and libraries which
must interact with a command line interface.

=head1 SYNOPSIS

 use Net::CLI::Interact;
 
 my $s = Net::CLI::Interact->new({
    personality => 'cisco',
    transport   => 'Telnet',
    connect_options => { host => '192.0.2.1' },
 });
 
 # respond to a usename/password prompt
 $s->macro('to_user_exec', {
     params => ['my_username', 'my_password'],
 });
 
 my $interfaces = $s->cmd('show ip interfaces brief');
 
 $s->macro('to_priv_exec', {
     params => ['my_password'],
 });
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

If you're a new user, please read the
L<Tutorial|Net::CLI::Interact::Manual::Tutorial>. There's also a
L<Cookbook|Net::CLI::Interact::Manual::Cookbook> and a L<Phrasebook
Listing|Net::CLI::Interact::Manual::Phrasebook>. For a more complete worked
example check out the L<Net::Appliance::Session> distribution, for which this
module was written.

=head1 INTERFACE

=head2 new( \%options )

Prepares a new session for you, but will not connect to any device. On
Windows platforms, you B<must> download the C<plink.exe> program, and pass
its location to the C<app> parameter. Other options are:

=over 4

=item C<< personality => $name >> (required)

The family of device command phrasebooks to load. There is a built-in library
within this module, or you can provide a search path to other libraries. See
L<Net::CLI::Interact::Manual::Phrasebook> for further details.

=item C<< transport => $backend >> (required)

The name of the transport backend used for the session, which may be one of
L<Telnet|Net::CLI::Interact::Transport::Telnet>,
L<SSH|Net::CLI::Interact::Transport::SSH>, or
L<Serial|Net::CLI::Interact::Transport::Serial>.

=item C<< connect_options => \%options >>

If the transport backend can take any options (for example the target
hostname), then pass those options in this value as a hash ref. See the
respective manual pages for each transport backend for further details.

=item C<< log_at => $log_level >>

To make using the C<logger> somewhat easier, you can pass this argument the
name of a log I<level> (such as C<debug>, C<info>, etc) and all logging in the
library will be enabled at that level. Use C<debug> to learn about how the
library is working internally. See L<Net::CLI::Interact::Logger> for a list of
the valid level names.

=back

=head2 cmd( $command )

Execute a single command statement on the connected device, and consume output
until there is a match with the current I<prompt>. The statement is executed
verbatim on the device, with a newline appended.

In scalar context the C<last_response> is returned (see below). In list
context the gathered response is returned, only split into a list on the
I<input record separator> (newline).

=head2 macro( $name, \%options? )

Execute the commands contained within the named Macro, which must be loaded
from a Phrasebook. Options to control the output, including variables for
substitution into the Macro, are passed in the C<%options> hash reference.

In scalar context the C<last_response> is returned (see below). In list
context the gathered response is returned, only split into a list on the
I<input record separator> (newline).

=head2 last_response

Returns the gathered output after the most recent C<cmd> or C<macro>. In
scalar context all data is returned. In list context the gathered response is
returned, only split into a list on the I<input record separator> (newline).

=head2 transport

Returns the L<Transport|Net::CLI::Interact::Transport> backend which was
loaded based on the C<transport> option to C<new>. See the
L<Telnet|Net::CLI::Interact::Transport::Telnet>,
L<SSH|Net::CLI::Interact::Transport::SSH>, or
L<Serial|Net::CLI::Interact::Transport::Serial> documentation for further
details.

=head2 phrasebook

Returns the Phrasebook object which was loaded based on the C<personality>
option given to C<new>. See L<Net::CLI::Interact::Phrasebook> for further
details.

=head2 set_phrasebook( \%options )

Allows you to (re-)configure the loaded phrasebook, perhaps changing the
personality or library, or other properties. The C<%options> Hash ref should
be any parameters from the L<Phrasebook|Net::CLI::Interact::Phrasebook>
module, but at a minimum must include a C<personality>.

=head2 set_default_contination( $macro_name )

Briefly, a Continuation handles the slurping of paged output from commands.
See the L<Net::CLI::Interact::Phrasebook> documentation for further details.

Pass in the name of a defined Contination (Macro) to enable paging handling as
a default for all sent commands. This is an alternative to describing the
Continuation format in each Macro.

To unset the default Continuation, call the C<clear_default_continuation>
method.

=head2 logger

This is the application's L<Logger|Net::CLI::Interact::Logger> object. A
powerful logging subsystem is available to your application, built upon the
L<Log::Dispatch> distribution. You can enable logging of this module's
processes at various levels, or add your own logging statements.

=head2 set_global_log_at( $level )

To make using the C<logger> somewhat easier, you can pass this method the
name of a log I<level> (such as C<debug>, C<info>, etc) and all logging in the
library will be enabled at that level. Use C<debug> to learn about how the
library is working internally. See L<Net::CLI::Interact::Logger> for a list of
the valid level names.

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
L<ActionSets|Net::CLI::Interact::ActionSet> (iterable sequences of Actions).
See those modules' documentation for further details, in case you wish to
introspect their structures.

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Role::Engine>

=back

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

