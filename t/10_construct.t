#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

BEGIN { use_ok( 'Net::CLI::Interact') }

my $s = new_ok('Net::CLI::Interact' =>[ 
    transport => 'Test'
]);

done_testing;
