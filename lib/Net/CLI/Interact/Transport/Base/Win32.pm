package Net::CLI::Interact::Transport::Base::Win32;
{
  $Net::CLI::Interact::Transport::Base::Win32::VERSION = '1.121990_002';
}

use Moose;
use Moose::Util::TypeConstraints;

extends 'Net::CLI::Interact::Transport::Base';

{
    package # hide from pause
        Net::CLI::Interact::Transport::Platform::Options;
    use Moose;
    extends 'Net::CLI::Interact::Transport::Base::Options';
}

use IPC::Run ();

has '_in' => (
    is => 'rw',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

# writer for the _in slot
sub put { ${ (shift)->_in } .= join '', @_ }

has '_out' => (
    is => 'ro',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

sub buffer {
    my $self = shift;
    return ${ $self->_out } if scalar(@_) == 0;
    return ${ $self->_out } = shift;
}

# clearer for the _out slot
has '_err' => (
    is => 'ro',
    isa => 'ScalarRef',
    default => sub { \eval "''" },
    required => 0,
);

has '_timeout_obj' => (
    is => 'ro',
    isa => 'IPC::Run::Timer',
    lazy_build => 1,
    required => 0,
);

sub _build__timeout_obj { return IPC::Run::timeout((shift)->timeout) }

has '+timeout' => (
    trigger => sub {
        (shift)->_timeout_obj->start(shift) if scalar @_ > 1;
    },
);

has '+wrapper' => (
    isa => 'IPC::Run',
    handles => ['pump'],
);

override '_build_wrapper' => sub {
    my $self = shift;

    $self->logger->log('transport', 'notice', 'booting IPC::Run harness for', $self->app);
    super();

    return IPC::Run::harness(
        [$self->app, $self->runtime_options],
            $self->_in,
            $self->_out,
            $self->_err,
            $self->_timeout_obj,
    );
};

before 'disconnect' => sub {
    my $self = shift;
    $self->wrapper->kill_kill(grace => 1);
};

1;
