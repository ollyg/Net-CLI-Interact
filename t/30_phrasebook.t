#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

use Net::CLI::Interact;

my $s = new_ok('Net::CLI::Interact' => [{
    transport => 'Test',
    personality => 'testing',
}]);

my $pb = $s->phrasebook;

ok(exists $pb->prompt->{'TEST_PROMPT_ONE'}, 'prompt exists');
ok(! exists $pb->prompt->{'TEST_PROMPT_XXX'}, 'prompt does not exist');

ok(exists $pb->macro->{'TEST_MACRO_ONE'}, 'macro exists');
ok(! exists $pb->macro->{'TEST_MACRO_XXX'}, 'macro does not exist');

done_testing;
