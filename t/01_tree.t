use Test::More tests => 28;
use strict; use warnings FATAL => 'all';

BEGIN {
  use_ok( 'IRC::Server::Tree' );
}

my $t = new_ok( 'IRC::Server::Tree' => [] );

## hubA
##  lhubA
##    lleafA
##    lleafB
##  leafA
## hubB
##  leafAA

## Adding nodes
ok($t->add_node_to_top('hubA'),             'add hubA'  );
ok($t->add_node_to_name('hubA', 'lhubA'),   'add lhubA' );
ok($t->add_node_to_name('hubA', 'leafA'),   'add leafA' );
ok($t->add_node_to_name('lhubA', 'lleafA'), 'add lleafA');
ok($t->add_node_to_name('lhubA', 'lleafB'), 'add lleafB');

ok($t->add_node_to_top( 'hubB' ),          'add hubB' );
ok($t->add_node_to_name('hubB', 'leafAA'), 'add lleafAA' );

## trace / trace_indexes
## Most other methods rely on these.
my $traced_hops;
ok($traced_hops = $t->trace_indexes('lleafB'), 'trace_indexes(lleafB)' );
ok(@$traced_hops == 3, 'trace_indexes returned 3 hops' );

my $traced_names;
ok($traced_names = $t->trace('lleafB'), 'trace(lleafB)' );
is_deeply($traced_names,
  [ 'hubA', 'lhubA', 'lleafB' ], 'trace() looks ok'
);

## as_hash
is_deeply($t->as_hash,
  {
    hubA => {
      lhubA => {
        lleafA => {},
        lleafB => {},
      },
      leafA => {},
    },
    hubB => {
      leafAA => {},
    },
  },
  'as_hash looks ok',
);


## as_list
cmp_ok($t->as_list, '==', 4, 'as_list returned values');

## child_node_for
is_deeply($t->child_node_for('lhubA'),
  [
    lleafA => [],
    lleafB => [],
  ],
  'child_node_for looks ok',
);

## del_node_by_name
## names_beneath NAME
## names_beneath REF
my $names_via_peername;
ok($names_via_peername = $t->names_beneath('lhubA'), 'names_beneath(NAME)' );
my @sorted = sort @$names_via_peername;
is_deeply(\@sorted, [ 'lleafA', 'lleafB' ], 'names_beneath(NAME) looks ok');
@sorted = ();

my $deleted;
ok($deleted = $t->del_node_by_name('lhubA'), 'del_node_by_name(lhubA)');

my $names;
ok($names = $t->names_beneath($deleted), 'names_beneath(REF)' );
ok(@$names, 'names_beneath(REF) returned names');
@sorted = sort @$names;
is_deeply(\@sorted, [ 'lleafA', 'lleafB' ], 'names_beneath(REF) looks ok');

## Rejoin deleted nodes under different hub
ok($t->add_node_to_name('hubB', 'newhub', $deleted),
  'add_node_to_name with deleted parent ref'
);

is_deeply($t->trace('lleafB'),
  [ 'hubB', 'newhub', 'lleafB' ],
  'trace() to readded lleafB looks ok'
);

my $hub_node;
ok($hub_node = $t->child_node_for('newhub'),
  'child_node_for newhub'
);

is_deeply($t->trace('lleafB', $hub_node), [ 'lleafB' ],
  'trace from newhub to lleafB looks ok'
);

{
  local *STDOUT;
  my $map;
  open *STDOUT, '+<', \$map;
  ok( $t->print_map, 'print_map returned true' );
  ok( $map, 'print_map wrote stdout' );
}
