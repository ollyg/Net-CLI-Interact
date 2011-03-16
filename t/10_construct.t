#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

BEGIN { use_ok( 'Net::CLI::Interact') }

new_ok('Net::CLI::Interact' => [ 
    transport => 'Test'
]);

new_ok('Net::CLI::Interact' => [{
    transport => 'Test'
}]);

done_testing;
