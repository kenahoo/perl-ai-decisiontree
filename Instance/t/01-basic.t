#!/usr/bin/perl

use strict;
use Test::More;

use AI::DecisionTree::Instance;
ok(1);

my $i = AI::DecisionTree::Instance->new([1, 2], 0, "foo");

is $i->value_int(0), 1, "Verify initial values are set correctly";
is $i->value_int(1), 2, "Verify initial values are set correctly";
is $i->result_int, 0, "Verify initial result is set correctly";
is $i->name, "foo", "Instance name is set correctly";

$i->set_value(0, 3);
is $i->value_int(0), 3, "Overwriting existing value works";

is $i->value_int(7), 0, "Grabbing value of nonexistant value index returns 0";
$i->set_value(7, 6);
is $i->value_int(7), 6, "set_value() on a new value index works correctly, expanding the value array";
is $i->value_int(5), 0, "set_value() defaulted to 0 on values in intermediate indexes";
is $i->value_int(1), 2, "value[1] is still set correctly";

is $i->set_value(9, 0), 0, "Don't bother expanding if the new value is zero";

$i = new AI::DecisionTree::Instance([4], 2, "bar");
is $i->value_int(0), 4, "New object replaces values";
is $i->result_int, 2, "New object replaces result";

done_testing;
