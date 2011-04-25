#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

use lib 't/lib';
use Net::CLI::Interact;

my $s = new_ok('Net::CLI::Interact' => [{
    transport => 'Test',
    personality => 'testing',
    add_library => 't/phrasebook',
}]);

$s->set_prompt('TEST_PROMPT_TWO'); # wrong!
ok(! eval { $s->cmd('TEST COMMAND', {timeout => 1} ) }, 'wrong prompt causes timeout');

# need to reinit the connection
ok($s->transport->disconnect, 'transport reinitialized');

my $out = $s->cmd('TEST COMMAND', {match => 'TEST_PROMPT'});
like($out, qr/^\d{10}$/, 'sent data with named custom match');

my $out2 = $s->cmd('TEST COMMAND', {match => qr/PROMPT>/});
like($out2, qr/^\d{10}$/, 'sent data with regexp custom match');

done_testing;
