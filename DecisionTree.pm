package AI::DecisionTree;
$VERSION = 0.02;

use 5.006;
use strict;
use Carp;

sub new {
  my $package = shift;
  return bless {
		noise_mode => 'fatal',
		@_,
		nodes => 0,
	       }, $package;
}

sub nodes      { $_[0]->{nodes} }
sub noise_mode { $_[0]->{noise_mode} }

sub add_instance {
  my ($self, %args) = @_;
  croak "Missing 'attributes' parameter" unless $args{attributes};
  croak "Missing 'result' parameter" unless defined $args{result};
  
  $self->{attributes}{$_}{$args{attributes}{$_}} = 1 foreach keys %{$args{attributes}};
  push @{$self->{instances}}, {%args};
}

sub train {
  my ($self) = @_;
  croak "Cannot train the same tree twice" if $self->{tree};
  croak "Must add training instances before calling train()" unless $self->{instances};
  
  $self->{tree} = $self->_expand_node( instances => $self->{instances} );
}

# Each node is:
#  { split_on => $attr_name,
#    children => { $attr_value1 => $node1,
#                  $attr_value2 => $node2, ... }
#  }
# or
#  { result => $result }

sub _expand_node {
  my ($self, %args) = @_;
  my @instances = @{$args{instances}};
  
  $self->{nodes}++;

  my %results;
  $results{$_->{result}}++ foreach @instances;
  if (keys(%results) == 1) {
    # All these instances have the same result - make this node a leaf
    return { result => $instances[0]->{result} };
  }

  my $node = {};
  
  # Multiple values are present - find the best predictor attribute and split on it
  $node->{split_on} = my $best_attr = $self->best_attr(\@instances);

  croak "Inconsistent data, can't build tree with noise_mode='fatal'"
    if $self->{noise_mode} eq 'fatal' and !defined $best_attr;

  # Pick the most frequent result for this leaf
  return { result => (sort {$results{$b} <=> $results{$a}} keys %results)[0] }
    unless defined $best_attr;
  
  my %split;
  foreach my $i (@instances) {
    push @{$split{ delete $i->{attributes}{$best_attr} }}, $i;
  }
  foreach my $opt (keys %split) {
    $node->{children}{$opt} = $self->_expand_node( instances => $split{$opt} );
  }

  return $node;
}

sub best_attr {
  my ($self, $instances) = @_;

  # 0 is a perfect score, entropy(#instances) is the worst possible score
  
  my ($best_score, $best_attr) = ($self->entropy( map $_->{result}, @$instances ), undef);
  foreach my $attr (keys %{$self->{attributes}}) {

    # %tallies is correlation between each attr value and result
    # %total is number of instances with each attr value
    my (%tallies, %totals);
    foreach (@$instances) {
      next unless exists $_->{attributes}{$attr};
      $tallies{$_->{attributes}{$attr}}{$_->{result}}++;
      $totals{$_->{attributes}{$attr}}++;
    }
    next unless keys %totals; # Make sure at least one instance defines this attribute
    
    my $score = 0;
    while (my ($opt, $vals) = each %tallies) {
      $score += $totals{$opt} / @$instances * $self->entropy2( $vals, $totals{$opt} )
    }

    ($best_attr, $best_score) = ($attr, $score) if $score < $best_score;
  }
  
  return $best_attr;
}

sub entropy2 {
  shift;
  my ($counts, $total) = @_;

  # Entropy is defined with log base 2 - we just divide by log(2) at the end to adjust.
  my $sum = 0;
  $sum += $_ * log($_) foreach values %$counts;
  return (log($total) - $sum/$total)/log(2);
}

sub entropy {
  shift;

  my %count;
  $count{$_}++ foreach @_;

  # Entropy is defined with log base 2 - we just divide by log(2) at the end to adjust.
  my $sum = 0;
  $sum += $_ * log($_) foreach values %count;
  return (log(@_) - $sum/@_)/log(2);
}

sub get_result {
  my ($self, %args) = @_;
  croak "Missing 'attributes' parameter" unless $args{attributes};
  
  $self->train unless $self->{tree};
  my $tree = $self->{tree};
  
  while (1) {
    return $tree->{result} if exists $tree->{result};
    return undef unless exists $args{attributes}{$tree->{split_on}};
    $tree = $tree->{children}{ $args{attributes}{$tree->{split_on}} }
      or return undef;
  }
}

sub rule_tree {
  my $self = shift;
  my ($tree) = @_ ? @_ : $self->{tree};
  
  # build tree:
  # [ question, { results => [ question, { ... } ] } ]
  
  return $tree->{result} if exists $tree->{result};
  
  return [
	  $tree->{split_on}, {
			      map { $_ => $self->rule_tree($tree->{children}{$_}) } keys %{$tree->{children}},
			     }
	 ];
}

sub rule_statements {
  my $self = shift;
  my ($stmt, $tree) = @_ ? @_ : ('', $self->{tree});
  return("$stmt -> '$tree->{result}'") if exists $tree->{result};
  
  my @out;
  my $prefix = $stmt ? "$stmt and" : "if";
  foreach my $val (keys %{$tree->{children}}) {
    push @out, $self->rule_statements("$prefix $tree->{split_on}='$val'", $tree->{children}{$val});
  }
  return @out;
}

1;
__END__

=head1 NAME

AI::DecisionTree - Automatically Learns Decision Trees

=head1 SYNOPSIS

  use AI::DecisionTree;
  my $dtree = new AI::DecisionTree;
  
  # A set of training data for deciding whether to play tennis
  $dtree->add_instance
    (attributes => {outlook     => 'sunny',
                    temperature => 'hot',
                    humidity    => 'high'},
     result => 'no');
  
  $dtree->add_instance
    (attributes => {outlook     => 'overcast',
                    temperature => 'hot',
                    humidity    => 'normal'},
     result => 'yes');

  ... repeat for several more instances, then:
  $dtree->train;
  
  # Find results for unseen instances
  my $result = $dtree->get_result
    (attributes => {outlook     => 'sunny',
                    temperature => 'hot',
                    humidity    => 'normal'});

=head1 DESCRIPTION

The C<AI::DecisionTree> module automatically creates so-called
"decision trees" to explain a set of training data.  A decision tree
is a kind of categorizer that use a flowchart-like process for
categorizing new instances.  For instance, a learned decision tree
might look like the following, which classifies for the concept "play
tennis":

                   OUTLOOK
                   /  |  \
                  /   |   \
                 /    |    \
           sunny/  overcast \rainy
               /      |      \
          HUMIDITY    |       WIND
          /  \       *no*     /  \
         /    \              /    \
    high/      \normal      /      \
       /        \    strong/        \weak
     *no*      *yes*      /          \
                        *no*        *yes*

(This example, and the inspiration for the C<AI::DecisionTree> module,
come directly from Tom Mitchell's excellent book "Machine Learning",
available from McGraw Hill.)

A decision tree like this one can be learned from training data, and
then applied to previously unseen data to obtain results that are
consistent with the training data.

The usual goal of a decision tree is to somehow encapsulate the
training data in the smallest possible tree.  This is motivated by an
"Occam's Razor" philosophy, in which the simplest possible explanation
for a set of phenomena should be preferred over other explanations.
Also, small trees will make decisions faster than large trees, and
they are much easier for a human to look at and understand.  One of
the biggest reasons for using a decision tree instead of many other
machine learning techniques is that a decision tree is a much more
scrutable decision maker than, say, a neural network.

The current implementation of this module uses an extremely simple
method for creating the decision tree based on the training instances.
It uses an Information Gain metric (based on expected reduction in
entropy) to select the "most informative" attribute at each node in
the tree.  This is essentially the ID3 algorithm, developed by
J. R. Quinlan in 1986.  The idea is that the attribute with the
highest Information Gain will (probably) be the best attribute to
split the tree on at each point if we're interested in making small
trees.

=head1 METHODS

=head2 Building and Querying the Tree

=over 4

=item new()

=item new(noise_mode => 'pick_best')

Creates a new decision tree object and returns it.

Accepts a parameter, C<noise_mode>, which controls the behavior of the
C<train()> method when "noisy" data is encountered.  Here "noisy"
means that two or more training instances contradict each other, such
that they have identical attributes but different results.

If C<noise_mode> is set to C<fatal> (the default), the C<train()>
method will throw an exception (die).  If C<noise_mode> is set to
C<pick_best>, the most frequent result at each noisy node will be
selected.

=item add_instance(attributes => \%hash, result => $string)

Adds a training instance to the set of instances which will be used to
form the tree.  An C<attributes> parameter specifies a hash of
attribute-value pairs for the instance, and a C<result> parameter
specifies the result.

=item train()

Builds the decision tree from the list of training instances.

=item get_result(attributes => \%hash)

Returns the most likely result (from the set of all results given to
C<add_instance()>) for the set of attribute values given.  An
C<attributes> parameter specifies a hash of attribute-value pairs for
the instance.  If the decision tree doesn't have enough information to
find a result, it will return C<undef>.

=back

=head2 Tree Introspection

=over 4

=item nodes()

Returns the number of nodes in the trained decision tree.

=item rule_tree()

Returns a data structure representing the decision tree.  For 
instance, for the tree diagram above, the following data structure 
is returned:

 [ 'outlook', {
     'rain' => [ 'wind', {
         'strong' => 'no',
         'weak' => 'yes',
     } ],
     'sunny' => [ 'humidity', {
         'normal' => 'yes',
         'high' => 'no',
     } ],
     'overcast' => 'yes',
 } ]

This is slightly remniscent of how XML::Parser returns the parsed 
XML tree.

Note that while the ordering in the hashes is unpredictable, the 
nesting is in the order in which the criteria will be checked at 
decision-making time.

=item rule_statements()

Returns a list of strings that describe the tree in rule-form.  For
instance, for the tree diagram above, the following list would be
returned (though not necessarily in this order - the order is
unpredictable):

  if outlook='rain' and wind='strong' -> 'no'
  if outlook='rain' and wind='weak' -> 'yes'
  if outlook='sunny' and humidity='normal' -> 'yes'
  if outlook='sunny' and humidity='high' -> 'no'
  if outlook='overcast' -> 'yes'

This can be helpful for scrutinizing the structure of a tree.

Note that while the order of the rules is unpredictable, the order of
criteria within each rule reflects the order in which the criteria
will be checked at decision-making time.

=back

=head1 LIMITATIONS

A few limitations exist in the current version.  All of them could be
removed in future versions - especially with your help. =)

=over 4

=item No continuous attributes

In the current implementation, only discrete-valued attributes are
supported.  This means that an attribute like "temperature" can have
values like "cool", "medium", and "hot", but using actual temperatures
like 87 or 62.3 is not going to work.  This is because the values
would split the data too finely - the tree-building process would
probably think that it could make all its decisions based on the exact
temperature value alone, ignoring all other attributes, because each
temperature would have only been seen once in the training data.

The usual way to deal with this problem is for the tree-building
process to figure out how to place the continuous attribute values
into a set of bins (like "cool", "medium", and "hot") and then build
the tree based on these bin values.  Future versions of
C<AI::DecisionTree> may provide support for this.  For now, you have
to do it yourself.

=item No support for tree-trimming

Most decision tree building algorithms use a two-stage building
process - first a tree is built that completely fits the training data
(or fits it as closely as possible if noisy data is supported), and
then the tree is pruned so that it will generalize well to new
instances.  This might be done either by maximizing performance on a
set of held-out training instances, or by pruning parts of the tree
that don't seem like they'll be very valuable.

Currently, we build a tree that completely fits the training data, and
we don't prune it.  That means that the tree may B<overfit> the
training data in many cases - i.e., you won't be able to see the
forest for the trees (or, more accurately, the tree for the leaves).

This is mainly a problem when you're using "real world" or noisy data.
If you're using data that you know to be a result of a rule-based
process and you just want to figure out what the rules are, the
current implementation should work fine for you.

=back

=head1 TO DO

All the stuff in the LIMITATIONS section, plus more.  For instance, it
would be nice to create a GraphViz (or Dot) graphical representation
of the tree.

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

Mitchell, Tom (1997).  Machine Learning.  McGraw-Hill. pp 52-80.

Quinlan, J. R. (1986).  Induction of decision trees.  Machine
Learning, 1(1), pp 81-106.

L<perl>.

=cut
