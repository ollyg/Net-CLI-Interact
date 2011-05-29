package Net::CLI::Interact::Transport;

use Moose;

BEGIN {
    sub is_win32 { return ($^O eq 'MSWin32') }

    extends (is_win32()
        ? 'Net::CLI::Interact::Transport::Base::Win32'
        : 'Net::CLI::Interact::Transport::Base::Unix');
}

1;
