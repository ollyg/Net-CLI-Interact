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
    my $pb = Net::CLI::Interact::Phrasebook->new({
        logger => $self->logger,
        $self->params,
    });
    $pb->load_phrasebooks;
    return $pb;
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
