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
    new_values = realloc(instance->values, attribute * sizeof(int));
    if (!new_values)
      croak("Couldn't grab new memory to expand instance");
    
    for (i=instance->num_values; i<attribute-1; i++)
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

AI::DecisionTree::Instance - C-struct wrapper for training instances

=head1 SYNOPSIS

  use AI::DecisionTree::Instance;
  
  my $i = new AI::DecisionTree::Instance({foo => 'fooey', bar=> 'barrey'}, 'sports');
  $i->value('foo') eq 'fooey';
  $i->value('bar') eq 'barrey';
  $i->result eq 'sports';
  
  $i->value_int(0) == 0;  # Integer versions of values and attributes
  $i->result_int == 0;    # Integer version of result

=head1 DESCRIPTION

This class is just a simple Perl wrapper around a C struct embodying a
single training instance.  Its purpose is to reduce memory usage.  In
a "typical" training set with about 1000 instances, memory usage can
be reduced by about a factor of 5 (from 43.7M to 8.2M in my test
program).

This class typically has little effect on training speed or
data-reading speed.  It's not really a speed increaser, it's a memory
saver.

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

AI::DecisionTree, Inline

=cut
