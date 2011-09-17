package Net::CLI::Interact::Transport::Base::Unix;
BEGIN {
  $Net::CLI::Interact::Transport::Base::Unix::VERSION = '1.112600';
}

use Moose;
use Moose::Util::TypeConstraints;

extends 'Net::CLI::Interact::Transport::Base';

{
    package # hide from pause
        Net::CLI::Interact::Transport::Platform::Options;
    use Moose;
    extends 'Net::CLI::Interact::Transport::Base::Options';

    has 'reap' => (
        is => 'rw',
        isa => 'Int',
        default => 0,
    );
}

has '+irs' => (
    trigger => sub {
        (shift)->wrapper->input_record_separator(shift) if scalar @_ > 1;
    },
);

has '+ors' => (
    trigger => sub {
        (shift)->wrapper->output_record_separator(shift) if scalar @_ > 1;
    },
);

sub put { (shift)->wrapper->put( join '', @_ ) }

has '_buffer' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    required => 0,
);

sub buffer {
    my $self = shift;
    return $self->_buffer if scalar(@_) == 0;
    return $self->_buffer(shift);
}

sub pump {
    my $self = shift;
    my $content = $self->wrapper->get;
    $self->_buffer($self->_buffer . $content);
}

has '+timeout' => (
    trigger => sub {
        (shift)->wrapper->timeout(shift) if scalar @_ > 1;
    },
);

has '+wrapper' => (
    isa => 'Net::Telnet',
);

override '_build_wrapper' => sub {
    my $self = shift;

    $self->logger->log('transport', 'notice', 'creating Net::Telnet wrapper for', $self->app);
    super();

    $SIG{CHLD} = 'IGNORE'
        if not $self->connect_options->reap;

    with 'Net::CLI::Interact::Transport::Role::ConnectCore';
    return $self->connect_core($self->app, $self->runtime_options);
};

1;
