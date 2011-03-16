#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

use Net::CLI::Interact;

my $s = Net::CLI::Interact->new({
    transport => 'Test',
});

ok($s->transport->connect);

done_testing;
