# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
BEGIN { plan tests => 5 };
use AI::DecisionTree;
ok(1); # If we made it this far, we're ok.

#########################

my @attributes = qw(outlook  temperature  humidity  wind    play_tennis);               
my @cases      = qw(
		    sunny    hot          high      weak    no
		    sunny    hot          high      strong  no
		    overcast hot          high      weak    yes
		    rain     mild         high      weak    yes
		    rain     cool         normal    weak    yes
		    rain     cool         normal    strong  no
		    overcast cool         normal    strong  yes
		    sunny    mild         high      weak    no
		    sunny    cool         normal    weak    yes
		    rain     mild         normal    weak    yes
		    sunny    mild         normal    strong  yes
		    overcast mild         high      strong  yes
		    overcast hot          normal    weak    yes
		    rain     mild         high      strong  no
		   );
my $outcome = pop @attributes;


my $dtree = new AI::DecisionTree;
while (@cases) {
  my @values = splice @cases, 0, 1 + scalar(@attributes);
  my $result = pop @values;
  my %pairs;
  @pairs{@attributes} = @values;

  $dtree->add_instance(attributes => \%pairs,
		       result => $result,
		      );
}
$dtree->train;


# Make sure a training example is correctly categorized
my $result = $dtree->get_result(
				attributes => {
					       outlook => 'rain',
					       temperature => 'mild',
					       humidity => 'high',
					       wind => 'strong',
					      }
			       );
ok($result, 'no');

# Try a new unseen example
my $result = $dtree->get_result(
				attributes => {
					       outlook => 'sunny',
					       temperature => 'hot',
					       humidity => 'normal',
					       wind => 'strong',
					      }
			       );
ok($result, 'yes');

# Make sure rule_statements() works
ok !!grep {$_ eq "if outlook='overcast' -> 'yes'"} $dtree->rule_statements;
#print map "$_\n", $dtree->rule_statements;

# Should barf on inconsistent data
my $t2 = new AI::DecisionTree;
$t2->add_instance( attributes => { foo => 'bar' },
		   result => 1 );
$t2->add_instance( attributes => { foo => 'bar' },
		   result => 0 );
eval {$t2->train};
ok( "$@", '/Inconsistent data/' );

