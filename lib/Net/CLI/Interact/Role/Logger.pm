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
