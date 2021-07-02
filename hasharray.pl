#!/usr/bin/perl -w
# use 5.010;
use strict;
use warnings;
no warnings 'uninitialized';

my %hash = ();
my $key = "mykey";
my $value = "quick";

# Push new var at the end of the array,
# again dereferencing the array.
push(@{ $hash{$key} }, $value);

print_hash();

$value = "brown";

push(@{ $hash{$key} }, $value);

print_hash();

# Extract the first element from the array.
my $extract = shift(@{$hash{$key}});

print "Extracted: $extract\n";

print_hash();

sub print_hash {

	# $_ being the running variable, 
	# we dereference the array from the  hash through @{...}
	foreach (keys %hash) {
	    print "$_: @{$hash{$_}}\n"; 
	}
}