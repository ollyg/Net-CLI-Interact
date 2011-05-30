package Net::CLI::Interact::Transport::Base;

use Moose;
use Moose::Util::TypeConstraints;

{
    package # hide from pause
        Net::CLI::Interact::Transport::Base::Options;
    use Moose;
}

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    required => 1,
);

has 'irs' => (
    is => 'ro',
    isa => 'Str',
    default => "\n",
    required => 0,
);

sub irs_re {
    my $self = shift;
    my $irs = $self->irs;
    return qr/$irs/;
}

has 'ors' => (
    is => 'ro',
    isa => 'Str',
    default => "\n",
    required => 0,
);

has 'timeout' => (
    is => 'rw',
    isa => subtype( 'Int' => where { $_ > 0 } ),
    required => 0,
    default => 10,
);

has 'app' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has 'stash' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    required => 0,
);

has 'wrapper' => (
    is => 'rw',
    isa => 'Object',
    lazy_build => 1,
    required => 0,
    predicate => 'connect_ready',
);

sub _build_wrapper {
    my $self = shift;
    $self->logger->log('transport', 'debug', 'command expands to: ',
        $self->app, (join ' ', map {($_ =~ m/\s/) ? ("'". $_ ."'") : $_}
                                   $self->runtime_options));
    # this better be wrapped otherwise it'll blow up
};

sub init { (shift)->wrapper(@_) }

sub flush {
    my $self = shift;
    my $content = $self->stash . $self->buffer;
    $self->stash('');
    $self->buffer('');
    return $content;
}

sub disconnect {
    my $self = shift;
    $self->clear_wrapper;
    $self->flush;
}

sub _abc { confess "not implemented." }

sub put { _abc() }
sub pump { _abc() }
sub buffer { _abc() }

sub DEMOLISH { (shift)->disconnect }

# see if any regexp in the arrayref match the response
sub _first_match {
    my ($text, $matches) = @_;
    $matches = ((ref $matches eq ref qr//) ? [$matches] : $matches);
    return undef unless
        (scalar grep {ref $_ eq ref qr//} @$matches) == scalar @$matches;

    use List::Util 'first';
    return first { $text =~ $_ } @$matches;
}

sub do_action {
    my ($self, $action) = @_;
    $self->logger->log('transport', 'info', 'callback received for', $action->type);

    if ($action->type eq 'match') {
        my $cont = $action->continuation;
        while ($self->pump) {
            $self->logger->log('dump', 'debug', "SEEN:\n". $self->buffer);

            my @out_lines = split $self->irs_re, $self->buffer;
            next if !defined $out_lines[-1];

            my $maybe_stash = join $self->irs, @out_lines[0 .. ($#out_lines - 1)];
            my $last_out = $out_lines[-1];

            if ($cont and $last_out =~ $cont->first->value) {
                $self->logger->log('transport', 'debug', 'continuation matched');
                $self->stash($self->flush);
                $self->put($cont->last->value);
            }
            elsif (my $hit = _first_match($last_out, $action->value)) {
                $self->logger->log('transport', 'debug',
                    sprintf 'output matched %s, storing and returning', $hit);
                # prompt match is line oriented. want to split that off from
                # rest of output which is marshalled into the 'send'.
                my @output = split $self->irs_re, $self->flush;
                $action->response_stash(join $self->irs, @output[0 .. ($#output - 1)]);
                $action->response($output[-1]);
                last;
            }
            else {
                $self->logger->log('transport', 'debug', "nope, doesn't (yet) match", $action->value);
                # put back the partial output and try again
                $self->stash( $self->stash . $maybe_stash );
                $self->buffer($last_out);
            }
        }
    }
    if ($action->type eq 'send') {
        my $command = sprintf $action->value, $action->params;
        $self->logger->log('transport', 'debug', 'queueing data for send: "'. $command .'"');
        $self->put( $command, ($action->no_ors ? () : $self->ors) );
    }
}

1;
