package
    Net::CLI::Interact::Transport::Role::Options;

use Moose::Role;

    has 'reap' => (
        is => 'rw',
        isa => 'Int',
        default => 0,
    );

1;
