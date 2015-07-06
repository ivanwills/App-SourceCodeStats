#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Warnings;

BEGIN {
    use_ok( 'App::SourceCodeStats' );
}

diag( "Testing App::SourceCodeStats $App::SourceCodeStats::VERSION, Perl $], $^X" );
done_testing();
