#!/usr/bin/perl
use 5.010_000;
use strict;
use warnings;

my $lhs;
while(<>) {
	if(/^(\w+)\s*:\s*(.*)/) {
		$lhs = $1;
		my $rhs = $2;
		$rhs =~ s/'//g;
		$rhs =~ s/\//\\\//g;
		$rhs =~ s/\[/open_brace/g;
		$rhs =~ s/\]/close_brace/g;
		say "{ lhs => '$lhs', rhs => [qw/$rhs/], },";
	}
	if(/^\| (.*)$/) {
		my $rhs = $1;
		$rhs =~ s/'//g;
		$rhs =~ s/\//\\\//g;
		$rhs =~ s/\[/open_brace/g;
		$rhs =~ s/\]/close_brace/g;
		say "{ lhs => '$lhs', rhs => [qw/$rhs/], },";
	}
}
