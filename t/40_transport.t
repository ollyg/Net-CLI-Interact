#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

use Net::CLI::Interact;

my $s = new_ok('Net::CLI::Interact' => [{
    transport => 'Test',
    personality => 'testing',
    log_at => 'debug',
}]);

$s->set_prompt('TEST_PROMPT');

my $out = $s->cmd('TEST COMMAND');
like($out, qr/^\d{10}$/, 'sent data and it was echoed and captured');

#use Data::Dumper;
#print Dumper $s->last_actionset;

done_testing;
