package Net::CLI::Interact::Transport;

use Moose;

BEGIN {
    sub is_win32 { return ($^O eq 'MSWin32') }

    extends (is_win32()
        ? 'Net::CLI::Interact::Transport::Base::Win32'
        : 'Net::CLI::Interact::Transport::Base::Unix');
}

{
    package # hide from pause
        Net::CLI::Interact::Transport::Options;
    use Moose;
    extends 'Net::CLI::Interact::Transport::Platform::Options';
}

1;
