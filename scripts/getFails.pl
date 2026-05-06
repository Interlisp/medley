#!/usr/bin/env perl
use strict;
use warnings;

die "Usage: $0 <pattern1> <pattern2> [file...]\n" unless @ARGV >= 2;

my $pat1 = shift;
my $pat2 = shift;
my $regex1line = qr/${pat1}.*?${pat2}/; # all on 1 line
my $regexStart = qr/${pat1}/;            # the line has the start pattern
my $regexEnd = qr/${pat2}/;              # the line has the end pattern

my $flag = 0;

while (<>) {
    if ($flag) {                          # we're in a multi-line block
        print;
        if (/$regexEnd/) {               # does this line end the multi-line block?
            $flag = 0;
            print "\n";                   # separator
        };
    }
    elsif (/$regex1line/) {             # all on 1 line
        print;
        print "\n";                      # separator
    }
    elsif (/$regexStart/) {             # begin a multi-line block
        print;
        $flag = 1;
    }
}