#!/usr/bin/perl -w

# (c) Copyright 2015 http://reddit/user/k-h

# Released under GPL 3.0 
# http://www.gnu.org/licenses/agpl-3.0.html
#
# this is a perl script and requires perl to run
# it has been tested on a linux system.
# It also requires lynx and uses head and wc
# and a dictionary in plain text

if ($] < 5.012003)
  { die "This script needs perl 5.12 or greater"; }

use strict;
use Getopt::Long;

Getopt::Long::Configure
  (qw/no_ignore_case require_order no_auto_abbrev/);

my $help=0;
my $verbose = 0;
my @sleep = ();
my @words = ();
my @lines = ();
my $dicts = '';
my $dict="/usr/share/dict/words";

GetOptions (
  'help|h' => \$help,
  'verbose|v+' => \$verbose,
  'sleep|s=i{1,2}' => \@sleep,
  'words|w=i{1,2}' => \@words,
  'lines|l=i{1,2}' => \@lines,
  'dictionary|d=s' => \$dicts
) or die ("Error in commandline arguments\n");

my $verbose_error = 0;
sub fail_usage {
  my (@mess) = @_;
  my $name = $0;
  $name =~ s#^.*/(.+)$#$1#;

  for (@mess) { print STDERR "$name Error : $_ \n"; }
  if ($verbose_error) {
    print STDERR <<EOM;
Usage : $name  -h|--help
Usage : $name 

  This program does a google search and makes a list of 
  websites and then one by one makes a connection 
  to each website and downloads a small amount of data
  to generate a metadata connection.

  options: [-w|--words <min[, max]>] default 1,3
           [-l|--lines <min[, max]>] default 6,10
           [-s|--sleep <min[, max]>] default 1,2
           [-d|--dictionary <path-to-file>] default /usr/share/dict/words
           [-h|--help]
           [-v|--verbose]            default 0

    -v|--verbose - be more talkative
                   mainly for debugging
    -h|--help - print this info
    -s|--sleep - seconds between calls
    -w|--words - min and max words for google search
              a random number of words from a dictionary is chosen
              for a google search.  Default is between 1 and 3
    -l|--lines - min and max lines of data for each connection 
              to download.

examples:
   $name
   $name -s 1 2 -w 1 4 -s 6 15

   while 1; do $name; sleep 60; done &

EOM
  }
  exit 1;
}

if ($help) { $verbose_error=1; &fail_usage (); }

if (3 < $verbose) {
  print "arguments were:\n";
  print "lines=", join (',', @lines), "\n";
  print "words=", join (',', @words), "\n";
  print "sleep=", join (',', @sleep), "\n";
  print "dict='$dict'\n";
  print "dicts='$dicts'\n";
  print "verbose=$verbose\n";
  print "ARGS=", join (',', @ARGV), "\n";
}

if ($dicts) { 
  if (-r $dicts) { $dict = $dicts; }
  else { fail_usage "Cannot read dictionary \"$dicts\""; }
}
elsif (! -r $dict) { fail_usage "Cannot find dictionary \"$dict\""; }

if (scalar @sleep) {
  # number of sleep seconds between websites should not be negative, nor too big 
  if ($sleep[0] < 0  or 3600 < $sleep[0] ) { $sleep[0] = 1; }
  if (!defined($sleep[1])) { $sleep[1] = $sleep[0]; }
  elsif ($sleep[1]<$sleep[0]) { $sleep[1] =  $sleep[0]; }
}
else { @sleep = (1, 2); }
if (scalar @words) {
  # number of words to search for should not be negative, zero, nor too big 
  if ($words[0] <=0  or 5 < $words[0] ) { $words[0] = 1; }
  if (!defined($words[1])) { $words[1] = $words[0]; }
  elsif ($words[1]<$words[0]) { $words[1] =  $words[0]; }
  elsif (8 < $words[1]) { $words[1] = 8; }
}
else { @words = (1, 3); }
if (scalar @lines) {
  # number of lines should not be negative
  if ($lines[0] < 0) { $lines[0] = 1; }
  if (!defined($lines[1])) { $lines[1] = $lines[0]; }
  elsif ($lines[1]<$lines[0]) { $lines[1] =  $lines[0]; }
}
else { @lines = (6,10); }
if (scalar @ARGV) { fail_usage "arguments not understood (" . join(',',@ARGV) . ")"; } 

if (1 < $verbose) {
  print "arguments were:\n";
  print "lines=", join (',', @lines), "\n";
  print "words=", join (',', @words), "\n";
  print "sleep=", join (',', @sleep), "\n";
  print "dict='$dict'\n";
  print "dicts='$dicts'\n";
  print "verbose=$verbose\n";
  print "ARGS=", join (',', @ARGV), "\n";
}

my $wordc = $words[0]; 
if (defined ($words[1]))
  { $wordc = int(rand($words[1]+1-$words[0]))+$words[0]; } # between $words[0] and $words[1] words

sub getdictnumwords {
  my $dlines=0;
  my $FILE;
  open ($FILE, $dict) or fail_usage "Can't open dictionary '$dict': $!";
  while (<$FILE>) { if ($_) { $dlines++; } }
  close $FILE;
  return $dlines;
}

my $dlines = getdictnumwords;
if (1<$verbose) { print "words=(",$wordc,") dict=($dlines)\n"; }


my @wordps = ();
map { push @wordps, int(rand($dlines)); } (1..$wordc);

my @wordpss = sort {$a<=>$b} @wordps;
if (1<$verbose) { print "wordpss ", join (", ",@wordpss), "\n"; }

sub getwords {
  my @wordpss = @_;

  my @words = ();
  my $line=0;

  my $FILE;
  open ($FILE, $dict) or die "Can't open dictionary '$dict': $!";
  while (<$FILE>) {
    if (!$_) { next; }
    if ($line == $wordpss[0]) {
      chomp;
      push @words, $_;
      shift @wordpss; 
      if (!scalar @wordpss) { last; }
    }
    $line++;
  }
  close $FILE;
  return @words;
}

my $words = join ("+", getwords (@wordpss));

if (1<$verbose) { print "words ", $words, "\n"; }
$words =~ s/[^+a-z0-9-]//gi;
$words =~ s/\s+/+/gi;
if ($verbose) { print "words ", $words, "\n"; }

my @out = split /\n/, `echo "&num=100\n&pws=0\n---"|lynx -get_data -dump http://www.google.com/search?q=$words`;

my @out1 = grep /http/, @out;
# remove google redirections and get the target links
map {
  s/^[0-9\. ]*//;
  s#https?://[a-z0-9]+\.google\.com(\.au)?/.*http#http#i;
  s#\&.*$##;
  s# -.*$##i;
} @out1;
# don't want links to google sites, also shortened links, links with "..."
my @out3 = grep !/google[a-z]*\.com/ && !/youtube\.com/ && !m{\.\.\.}, @out1;
my %out = ();
map { $out{$_}++; } @out3;
my @outu = (sort { $a cmp $b } keys %out);
if (1<$verbose) { print join ("\n", @outu), "\n"; }

my $head = $lines[0];
my $sleeper=$sleep[0];

for my $i (@outu) {
  if (defined ($lines[1]))
    { $head = int(rand($lines[1]+1-$lines[0]))+$lines[0]; }
    # between $lines[0] and $lines[1] lines
  if (defined ($sleep[1]))
    { $sleeper = int(rand($sleep[1]+1-$sleep[0]))+$sleep[0]; }
    # between $sleep[0] and $sleep[1] sleep
  if ($verbose) { print "\n--------------s=$sleeper--h=$head---\n$i\n"; }
  if ($i !~ m#^https?://#ai) { next; }
  if (2<$verbose) { system ("lynx -dump '$i' | head -$head"); }
  elsif ($verbose) { system ("lynx -dump '$i' | head -$head | wc"); }
  else { system ("lynx -dump '$i' | head -$head > /dev/null"); }
  sleep $sleeper;
}

