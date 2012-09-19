package Net::CLI::Interact::Transport::Base::Unix;

use Moo;
use Sub::Quote;
use MooX::Types::MooseLike::Base qw(Str InstanceOf);

extends 'Net::CLI::Interact::Transport::Base';

{
    package # hide from pause
        Net::CLI::Interact::Transport::Platform::Options;

    use Moo;
    use Sub::Quote;
    use MooX::Types::MooseLike::Base qw(Int);

    extends 'Net::CLI::Interact::Transport::Base::Options';

    has 'reap' => (
        is => 'rw',
        isa => Int,
        default => quote_sub('0'),
    );
}

sub put { (shift)->wrapper->put( join '', @_ ) }

has '_buffer' => (
    is => 'rw',
    isa => Str,
    default => quote_sub(q{''}),
);

sub buffer {
    my $self = shift;
    return $self->_buffer if scalar(@_) == 0;
    return $self->_buffer(shift);
}

sub pump {
    my $self = shift;
    my $content = $self->wrapper->get;
    $self->_buffer($self->_buffer . $content) if defined $content;
}

has '+timeout' => (
    trigger => quote_sub(q{(shift)->wrapper->timeout(shift) if scalar @_ > 1}),
);

has '+wrapper' => (
    isa => InstanceOf['Net::Telnet'],
);

around '_build_wrapper' => sub {
    my ($orig, $self) = (shift, shift);

    $self->logger->log('transport', 'notice', 'creating Net::Telnet wrapper for', $self->app);
    $self->$orig(@_);

    $SIG{CHLD} = 'IGNORE'
        if not $self->connect_options->reap;

    with 'Net::CLI::Interact::Transport::Role::ConnectCore';
    return $self->connect_core($self->app, $self->runtime_options);
};

1;
