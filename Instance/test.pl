#!/usr/bin/perl

use Test;
BEGIN { plan tests => 8 }

use AI::DecisionTree::Instance;
ok(1);

my $i = new AI::DecisionTree::Instance({foo => 'fooey', bar=> 'barrey'}, 'sports');
ok $i->value('foo'), 'fooey';
ok $i->value('bar'), 'barrey';
ok $i->result, 'sports';

$i->delete_value('foo');
ok $i->value('foo'), undef;

$i = new AI::DecisionTree::Instance({foo => 'foo2'}, 'nature');
ok $i->value('foo'), 'foo2';
ok $i->value('bar'), undef;
ok $i->result, 'nature';

