#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

use Net::CLI::Interact;

my $s = new_ok('Net::CLI::Interact' => [{
    transport => 'Test',
    personality => 'testing',
}]);
$s->log_at('debug');

$s->set_prompt('MATCH_ANY');

my $out = $s->cmd('TEST END');
is($out, 'TEST END', 'sent data and it was echoed and captured');

use Data::Dumper;
print Dumper $s->last_actionset;

done_testing;
