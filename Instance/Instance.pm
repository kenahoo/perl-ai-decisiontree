package AI::DecisionTree::Instance;
BEGIN {
  $VERSION = '0.03';
  @ISA = qw(DynaLoader);
}

use strict;
use vars qw($VERSION @ISA);
use DynaLoader ();

bootstrap AI::DecisionTree::Instance $VERSION;

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
