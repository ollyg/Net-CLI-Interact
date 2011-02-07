package Net::CLI::Interact::Role::Logger;

use Moose::Role;
use Time::HiRes qw(gettimeofday tv_interval);
use Log::Dispatch::Config; # loads Log::Dispatch
use Log::Dispatch::Configurator::Any;

has log_config => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1,
);

sub _build_log_config {
    return {
        dispatchers => ['screen'],
        screen => {
            class => 'Log::Dispatch::Screen',
            min_level => 'debug',
        },
    };
}

has _logger => (
    is => 'ro',
    isa => 'Log::Dispatch::Config',
    lazy_build => 1,
);

# this allows each instance of this module to have its own
# wrapped logger with different configuration.
sub _build__logger {
    my $self = shift;

    use Class::MOP::Class;
    my $meta = Class::MOP::Class->create_anon_class(
        superclasses => ['Moose::Object', 'Log::Dispatch::Config'],
    );

    my $config = Log::Dispatch::Configurator::Any->new($self->log_config);
    $meta->name->configure($config);
    return $meta->name->instance;
}

has 'log_stamps' => (
    is => 'rw',
    isa => 'Bool',
    required => 0,
    default => 1,
);

has 'log_start' => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 0,
    default => sub{ [gettimeofday] },
);

has 'log_flags' => (
    is => 'rw',
    isa => 'ArrayRef|HashRef[Str]',
    default => sub { {} },
);

my %code_for = (
    debug     => 0,
    info      => 1,
    notice    => 2,
    warning   => 3,
    error     => 4,
    critical  => 5,
    alert     => 6,
    emergency => 7,
);

sub would_log {
    my ($self, $category, $level) = @_;

    my $flags = (ref $self->log_flags eq ref []
        ? { map {$_ => 'error'} @{$self->log_flags} }
        : $self->log_flags
    );

    return 0 if !exists $flags->{$category};
    return ($code_for{ $level } >= $code_for{ $flags->{$category} });
}

sub log {
    my ($self, $category, $level, @msgs) = @_;
    return unless $self->would_log($category, $level);

    my $stamp = sprintf "%13s", ($self->log_stamps
        ? ('['. (sprintf "%.6f", (tv_interval $self->log_start, [gettimeofday])) .']')
        : ());

    $self->_logger->$level($stamp,
        (substr $category, 0, 1), (' ' x (2 - $code_for{$level})), (join ' ', @msgs));
    $self->_logger->$level("\n") if $msgs[-1] !~ m/\n$/;
}

1;

# ABSTRACT: Provides per-instance multi-target logging with categories

=head1 SYNOPSIS

 $self->log('category', 'level', @messages);

=head1 DESCRIPTION

This module implements a generic logging function, based on
L<Log::Dispatch::Config> but with additional options and configuration. Log
messages coming from your application are categorized, and each category can
be enabled/disabled separately and have its own log level (i.e. C<emergency>
.. C<debug>). High resolution timestamps can be added to log messages.

=head1 METHODS

=over 4

=item log($category, $level, @messages)

The combination of category and level determine whether the the log messages
are emitted to any of the log destinations. Destinations are set using the
C<log_config> method, and categories are configured using the C<log_flags>
method.

The C<@messages> will be joined by a space character, and a newline appended
if the last message doesn't contain one itself. Messages are prepended with
the first character of their C<$category>, and then indented proportionally to
their C<$level>.

=item log_config(\%config)

A C<Log::Dispatch::Config> configuration (hash ref), meaning multiple log
targets may be specified with different minimum level thresholds. There is a
default configuration which emits messages to standard output with no
minimum threshold:

 {
     dispatchers => ['screen'],
     screen => {
         class => 'Log::Dispatch::Screen',
         min_level => 'debug',
     },
 };


=item log_flags(\@categories | \%category_level_map)

The user is expected to specify which log categories they are interested in,
and at what levels. If a category is used in the application for logging but
not specified, then it is deemed disabled.

In the array reference form, the list should contain category names, and they
will all be mapped to the C<error> level. In the hash reference form, the keys
should be category names and the values log levels from the list below
(ordered such that each level "includes" the levels I<above>):

 emergency
 alert
 critical
 error
 warning
 notice
 info
 debug

Messages at or above the specified level will be passed on to the
C<Log::Dispatch> target, which may then specify an overriding threshold.

=item log_stamps($boolean)

Enable (default) or disable the display of high resolution interval timestamps
with each log message.

=item log_start([$seconds, $microseconds])

Time of the start for generating a time interval when logging stamps. Defaults
to the result of C<Time::HiRes::gettimeofday> in list context.

=item would_log($category, $level)

Returns True if, according to the current C<log_flags>, the given C<$category>
is enabled at or above the threshold of C<$level>, otherwise returns False.
Note that the C<Log::Dispatch> targets maintain their own thresholds as well.

=back
