package AI::DecisionTree::Instance;
BEGIN {
  $VERSION = '0.01';
}

use 5.006;
use strict;
use vars qw($VERSION);
use Inline C => <<'END', NAME => __PACKAGE__, VERSION => $VERSION, CLEAN_AFTER_BUILD => 0;

typedef struct {
  int result;
  int num_values;
  int *values;
} Instance;

Instance *new_struct (char *class, int result, SV *values_ref) {
  Instance* instance = malloc(sizeof(Instance));
  AV* values = (AV*) SvRV(values_ref);
  int i;

  instance->result = result;
  instance->num_values = 1 + av_len(values);
  instance->values = malloc(instance->num_values * sizeof(int));

  for(i=0; i<instance->num_values; i++) {
    instance->values[i] = (int) SvIV( *av_fetch(values, i, 0) );
  }

  return instance;
}

void _set_value (Instance* instance, int attribute, int value) {
  int *new_values;
  int i;

  if (attribute >= instance->num_values) {
    if (!value) return; /* Nothing to do */
    
    printf("Expanding from %d to %d places\n", instance->num_values, attribute);
    new_values = malloc(attribute * sizeof(int));
    for (i=0; i<instance->num_values; i++)
      new_values[i] = instance->values[i];
    for (i=instance->num_values; i<attribute; i++)
      new_values[i] = 0;
    free(instance->values);
    instance->values = new_values;
    instance->num_values = 1 + attribute;
  }

  instance->values[attribute] = value;
}

int value_int (Instance *instance, int attribute) {
  if (attribute >= instance->num_values) return 0;
  return instance->values[attribute];
}

int result_int (Instance *instance) {
  return instance->result;
}

void DESTROY (Instance *instance) {
  free(instance->values);
  free(instance);
}

END



my %RESULTS;
my %ATTRIBUTES;
my %ATTRIBUTE_VALUES;
my %XBACK;

sub new {
  my ($package, $attributes, $result) = @_;
  
  my (@attributes);
  while (my ($k, $v) = each %$attributes) {
    $attributes[ _hlookup(\%ATTRIBUTES, $k) ] = _hlookup($ATTRIBUTE_VALUES{$k} ||= {}, $v);
  }
  $_ ||= 0 foreach @attributes;

  return $package->new_struct( _hlookup(\%RESULTS, $result), \@attributes );
}

sub all_attributes {
  return \%ATTRIBUTES;
}

sub delete_value {
  my ($self, $attr) = @_;
  my $val = $self->value($attr);
  return unless defined $val;
  
  $self->_set_value($ATTRIBUTES{$attr}, 0);
  return $val;
}

sub value {
  my ($self, $attr) = @_;
  return unless exists $ATTRIBUTES{$attr};
  my $val_int = $self->value_int($ATTRIBUTES{$attr});
  return $XBACK{$ATTRIBUTE_VALUES{$attr}}[$val_int];
}

sub result {
  my $int = shift->result_int();
  return $XBACK{\%RESULTS}[$int];
}

sub _hlookup {
  my ($hash, $key) = @_;
  unless (exists $hash->{$key}) {
    $hash->{$key} = 1 + keys %$hash;
    $XBACK{"$hash"}[ $hash->{$key} ] = $key;  # WHEE!
  }
  return $hash->{$key};
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
