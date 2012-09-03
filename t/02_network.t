use Test::More tests => 26;
use strict; use warnings FATAL => 'all';

BEGIN {
  use_ok( 'IRC::Server::Tree' );
  use_ok( 'IRC::Server::Tree::Network' );
}

new_ok( 'IRC::Server::Tree::Network' => [
  memoize => 0,
  tree    => IRC::Server::Tree->new,
]);

new_ok( 'IRC::Server::Tree::Network' => [
  IRC::Server::Tree->new
]);

my $net = new_ok( 'IRC::Server::Tree::Network' );

ok($net->tree->isa('IRC::Server::Tree'), 'has tree()' );

ok( $net->add_peer_to_self('hubA'),
  'add_peer_to_self(hubA)'
);

ok( $net->add_peer_to_name('hubA', 'lhubA'),
  'add_peer_to_name(hubA, lhubA)'
);

ok( $net->add_peer_to_name('hubA', 'lleafA'),
  'add_peer_to_name(hubA, lleafA)'
);

ok( $net->add_peer_to_name('lhubA', 'lhubleafA'),
  'add_peer_to_name(lhubA, lhubleafA)'
);

ok( $net->add_peer_to_self('hubB'),
  'add_peer_to_self(hubB)'
);

ok( $net->add_peer_to_name('hubB', 'leafB'),
  'add_peer_to_name(hubB, leafB)'
);

is_deeply( $net->tree->as_hash,
  {
    hubA => {
      lhubA => {
        lhubleafA => {},
      },
      lleafA => {},
    },
    hubB => {
      leafB => {},
    },
  },
  'tree as_hash looks ok'
);

## have_peer
ok(!$net->have_peer('NotPeer'), 'do not have_peer' );
ok($net->have_peer('lhubleafA'), 'have_peer lleafA' );

## hop_count
cmp_ok($net->hop_count('lhubleafA'), '==', 3,
  'hop_count for lhubleafA is 3'
);
cmp_ok($net->hop_count('hubB'), '==', 1,
  'hop_count for hubB is 1'
);

## trace
{
  my $traced;
  ok($traced = $net->trace('lhubleafA'), 'trace lhubleafA' );
  is_deeply($traced, ['hubA', 'lhubA', 'lhubleafA' ],
    'trace() to lhubleafA looks ok'
  );

  ## should've been memoized
  my $second;
  ok($second = $net->trace('lhubleafA'), 'trace lhubleafA');
  is_deeply($second, $traced, 'second trace() looks ok' );

  is_deeply($net->trace('leafB'),
    [ 'hubB', 'leafB' ],
    'trace() to leafB looks ok'
  );

  is_deeply($net->trace('leafB'),
    [ 'hubB', 'leafB' ],
    'second trace() to leafB looks ok'
  );
}

## split_peer
{
 my $splitnames;
 ok($splitnames = $net->split_peer('hubA'), 'split_peer hubA');
 my @sorted = sort @$splitnames;
 is_deeply(\@sorted, ['lhubA', 'lhubleafA', 'lleafA' ],
   'split_peer names look ok'
 );

  ok(!$net->trace('lhubleafA'), 'route to hubleafA was cleared');
}

## tree fuckery and reset_tree
## FIXME test exception thrown with invalid tree
## FIXME test with cloned/partial trees
## FIXME new() variation tests
## FIXME test for memoize => 0
