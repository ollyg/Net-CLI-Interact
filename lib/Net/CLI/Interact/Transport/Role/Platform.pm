package Net::CLI::Interact::Transport::Role::Platform;

use Moose;

BEGIN {
    my $p = ($ENV{NCI_P} || $^O);
    with ($p eq 'Win32'
        ? 'Net::CLI::Interact::Transport::Role::Win32'
        : 'Net::CLI::Interact::Transport::Role::Unix' );
}

1;
