#!/usr/bin/perl

use strict;
use AI::DecisionTree;
use Statistics::Contingency;

my $t = AI::DecisionTree->new(noise_mode => 'pick_best');


open my $fh, "spam/mixed" or die "spam/mixed: $!";
my @attr_names = split ',', scalar <$fh>;
chomp $attr_names[-1];

my $num_read = shift || 100;

while (<$fh>) {
  last if $. > $num_read; # Only first N instances for now

  my ($attr, $result) = parse_line($_);
  $t->add_instance(attributes => $attr, result => $result);
}

print "Training...\n";
#<STDIN>;
$t->train;
print "done\n";
#<STDIN>;

#use YAML; print Dump $t->rule_tree;
my $stats = new Statistics::Contingency(categories => ['spam','nonspam']);

my ($good, $bad, @checked) = (0,0);
while (<$fh>) {
  last if $. > 2 * $num_read;
  my ($attr, $result) = parse_line($_);
  
  my ($guess, $confidence, $checked) = $t->get_result(attributes => $attr);
  $stats->add_result($guess, $result);
  push @checked, $checked;
  
  print STDERR '.';
  #print "$guess : $result : $confidence\n";
}

print $stats->stats_table;
my $sum = 0;
$sum += $_ for @checked;
print "Average rule checks=", $sum/@checked, "\n";
use YAML; print Dump($stats->category_stats);

if (0) {
  # This stuff will only work on Mac OS X
  my $file = '/tmp/tree-spam.png';
  open my($fh), "> $file" or die "$file: $!";
  print $fh $t->as_graphviz->as_png;
  close $fh;
  system('open', $file);
}


######################################################################3
sub parse_line {
  my @values = split ',', $_[0];
  my $result = pop @values;
  chomp $result;
  
  my %attr;
  @attr{ @attr_names } = @values;
  return \%attr, $result;
}
