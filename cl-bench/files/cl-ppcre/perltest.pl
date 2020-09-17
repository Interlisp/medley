#!/usr/bin/perl

# This is a heavily modified version of the file 'perltest' which
# comes with the PCRE library package, which is open source software,
# written by Philip Hazel, and copyright by the University of
# Cambridge, England.

# The PCRE library package is available from
# <ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/>

use Time::HiRes qw(time);

sub string_for_lisp {
  my(@a, $t, $in_string, $switch);

  my $string = shift;
  $string =~ s/\\/\\\\/g;
  $string =~ s/"/\\"/g;

  $in_string = 1;
  foreach $c (split(//, $string)) {
    if (ord $c >= 32 && ord $c < 127) {
      if ($in_string) {
        $t .= $c;
      } else {
        $in_string = 1;
        $t = $c;
      }
    } else {
      if ($in_string) {
        push @a, "\"$t\"";
        $in_string = 0;
        $switch = 1;
      }
      push @a, sprintf("(list (code-char %d))", ord $c);
    }
  }
  if ($switch) {
    if ($in_string) {
      push @a, "\"$t\"";
    }
    "(cl-ppcre::string-list-to-simple-string (let (list) " . (join ' ', map {"(push $_ list)"} @a) . "(nreverse list)))";
  } else {
    "\"$t\"";
  }
}

$min_time = shift;

print "(defparameter cl-ppcre-test::*testdata* nil)\n";

NEXT_RE: while (1) {
  last
    if !($_ = <>);
  next
    if $_ eq "";

  $pattern = $_;

  while ($pattern !~ /^\s*(.).*\1/s) {
    last
      if !($_ = <>);
    $pattern .= $_;
  }

  chomp($pattern);
  $pattern =~ s/\s+$//;
  $pattern =~ s/\+(?=[a-z]*$)//;

  $multi_line_mode = ($pattern =~ /m[a-z]*$/) ? 't' : 'nil';
  $single_line_mode = ($pattern =~ /s[a-z]*$/) ? 't' : 'nil';
  $extended_mode = ($pattern =~ /x[a-z]*$/) ? 't' : 'nil';
  $case_insensitive_mode = ($pattern =~ /i[a-z]*$/) ? 't' : 'nil';
  $pattern =~ s/^(.*)g([a-z]*)$/\1\2/;

  $pattern_for_lisp = $pattern;
  $pattern_for_lisp =~ s/[a-z]*$//;
  $pattern_for_lisp =~ s/^\s*(.)(.*)\1/$2/s;
  $pattern_for_lisp =~ s/\\/\\\\/g;
  $pattern_for_lisp =~ s/"/\\"/g;

  $pattern = "/(?#)/$2"
    if ($pattern =~ /^(.)\1(.*)$/);

  while (1) {
    last NEXT_RE
      if !($_ = <>);

    chomp;

    s/\s+$//;
    s/^\s+//;

    last
      if ($_ eq "");

    $info_string = string_for_lisp "\"$_\" =~ $pattern";
    $x = eval "\"$_\"";

    @subs = ();

    eval <<"END";
if (\$x =~ ${pattern}) {
  push \@subs,\$&;
  push \@subs,\$1;
  push \@subs,\$2;
  push \@subs,\$3;
  push \@subs,\$4;
  push \@subs,\$5;
  push \@subs,\$6;
  push \@subs,\$7;
  push \@subs,\$8;
  push \@subs,\$9;
  push \@subs,\$10;
  push \@subs,\$11;
  push \@subs,\$12;
  push \@subs,\$13;
  push \@subs,\$14;
  push \@subs,\$15;
  push \@subs,\$16;
}

\$test = sub {
  my \$times = shift;

  my \$start = time;
  for (my \$i = 0; \$i < \$times; \$i++) {
    \$x =~ ${pattern};
  }
  return time - \$start;
};
END

    $times = 1;
    $used = 0;
    $counter++;
    print STDERR "$counter\n";

    if ($@) {
      $error = 't';
    } else {
      $error = 'nil';
      if ($min_time) {
        $times = 10;
        while (1) {
          $used = &$test($times);
          last
            if $used > $min_time;
          $times *= 10;
        }
      }
    }

    print "(push (list $counter $info_string \"$pattern_for_lisp\" $case_insensitive_mode $multi_line_mode $single_line_mode $extended_mode " . string_for_lisp($x) . " $error $times $used ";
    if (!@subs) {
      print 'nil nil';
    } else {
      print string_for_lisp($subs[0]) . ' (list';
      undef $not_first;
      for ($i = 1; $i <= 16; $i++) {
        print ' ';
        if (defined $subs[$i]) {
          print string_for_lisp $subs[$i];
        } else {
          print 'nil';
        }
      }
      print ')';
    }
    print ") cl-ppcre-test::*testdata*)\n";
  }
}

print "(setq cl-ppcre-test::*testdata* (nreverse cl-ppcre-test::*testdata*))\n";
