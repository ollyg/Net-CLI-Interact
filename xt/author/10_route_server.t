#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

BEGIN { use_ok( 'Net::CLI::Interact') }

my $s = Net::CLI::Interact->new(
    transport => "Telnet",
    ($^O eq 'MSWin32' ?
        (app => '..\..\..\Desktop\plink.exe') : () ),
    connect_options => { host => "route-server.bb.pipex.net" },
    personality => "cisco",
);

ok( $s->cmd('show ip bgp 163.1.0.0/16'), 'ran show ip bgp 163.1.0.0/16' );

like( $s->last_prompt, qr/\w+ ?>$/, 'command ran and prompt looks ok' );

my @out = $s->last_response;
cmp_ok( scalar @out, '>=', 5, 'sensible number of lines in the command output');

done_testing;
