package IRC::Server::Tree::Network;

## An IRC Network with route memoization and simple sanity checks
## IRC::Server::Tree lives in ->tree()

use strictures 1;

use Carp;
use Scalar::Util 'blessed';

use IRC::Server::Tree;

sub new {
  my $class = shift;

  my $memoize;
  my $tree = sub {

    if (@_ == 1) {
      my $item = $_[0];

      return $item
        if blessed($item) and $item->isa('IRC::Server::Tree');

      return IRC::Server::Tree->new($item)
        if ref $item eq 'ARRAY';
    } elsif (@_ > 1) {
      ## Given named opts, we hope.
      ##  memoize => Bool
      ##  tree    => IRC::Server::Tree
      my %opts = @_;
      $opts{lc $_} = delete $opts{$_} for keys %opts;

      $memoize = $opts{memoize} || 1;

      return IRC::Server::Tree->new(
        $opts{tree} ? delete $opts{tree} : ()
      )
    }

    return IRC::Server::Tree->new
  };

  my $self = {
    tree    => $tree->(@_),
    memoize => $memoize,
  };

  bless $self, $class;

  ## Set up ->{seen}
  $self->reset_tree;

  $self
}

sub reset_tree {
  my ($self) = @_;

  ## Call me for a route clear / seen-item refresh
  ## (ie, after mucking around in the ->tree() )

  $self->{seen} = {};

  my $all_names = $self->tree->names_beneath( $self->tree );

  for my $name (@$all_names) {
    if (++$self->{seen}->{$name} > 1) {
      confess "Passed a broken Tree; duplicate node entries for $name"
    }
  }

  1
}

sub have_peer {
  my ($self, $peer) = @_;

  return 1 if $self->{seen}->{$peer};

  return
}

sub _have_route_for_peer {
  my ($self, $peer) = @_;

  return unless $self->{memoize};

  if (ref $self->{seen}->{$peer} eq 'ARRAY') {
    return $self->{seen}->{$peer}
  }

  return
}

sub add_peer_to_self {
  my ($self, $peer, $arrayref) = @_;

  confess "add_peer_to_self expects a peer name"
    unless defined $peer;

  if ( $self->have_peer($peer) ) {
    carp "Tried to add previously-seen node $peer";
    return
  }

  return unless
    $self->tree->add_node_to_top($peer, $arrayref);
  $self->{seen}->{$peer} = 1;
  $self->reset_tree if $arrayref;
  1
}

sub add_peer_to_name {
  my ($self, $parent_name, $new_name, $arrayref) = @_;

  ## FIXME
  ## Hmm.. currently no convenient way to use memoized routes
  ## when adding.
  ## Probably should have an add in Tree that can take numerical
  ## routes to the parent's ref.

  if ( $self->have_peer($new_name) ) {
    carp "Tried to add previously-seen node $new_name";
    return
  }

  return unless
    $self->tree->add_node_to_name($parent_name, $new_name, $arrayref);
  $self->{seen}->{$new_name} = 1;
  $self->reset_tree if $arrayref;
  1
}

sub hop_count {
  ## Returns a hop count as normally used in LINKS output and similar
  my ($self, $peer_name) = @_;

  my $path = $self->trace( $peer_name );
  return unless $path;

  scalar(@$path)
}

sub split_peer {
  ## Split a peer and return the names of all hops under it.
  my ($self, $peer) = @_;

  my $splitref = $self->tree->del_node_by_name( $peer ) || return;

  delete $self->{seen}->{$peer};

  my $names = $self->tree->names_beneath( $splitref );

  if ($names && @$names) {
    delete $self->{seen}->{$_} for @$names;
  }

  wantarray ? @$names : $names
}

sub trace {
  my ($self, $peer) = @_;

  if (my $routed = $self->_have_route_for_peer($peer) ) {
    return $self->tree->path_by_indexes( $routed )
  }

  ## FIXME maybe needs a switch via the memoize new() opt.
  ## If we memoize the indexes, we have to walk that path twice.
  ##  (a search to get indexes, a walk to get names)
  ## If we memoize the route, we spend more memory on hop names.
  my $index_route = $self->tree->trace_indexes( $peer );
  return unless ref $index_route eq 'ARRAY' and @$index_route;

  my $named_hops  = $self->tree->path_by_indexes( $index_route );
  return unless ref $named_hops eq 'ARRAY' and @$named_hops;

  $self->{seen}->{$peer} = $index_route if $self->{memoize};

  $named_hops
}

sub tree {
  my ($self) = @_;
  $self->{tree}
}

1;

=pod

=head1 NAME

IRC::Server::Tree::Network - An enhanced IRC::Server::Tree

=head1 SYNOPSIS

  ## Model a network
  my $net = IRC::Server::Tree::Network->new;

  ## Add a couple top-level peers
  $net->add_peer_to_self('hubA');
  $net->add_peer_to_self('leafA');

  ## Add some peers to hubA
  $net->add_peer_to_name('hubA', 'leafB');
  $net->add_peer_to_name('hubA', 'leafC');

  ## [ 'leafB', 'leafC' ] :
  my $split = $net->split_peer('hubA');

See below for complete details.

=head1 DESCRIPTION

An IRC::Server::Tree::Network provides simpler methods for interacting 
with an L<IRC::Server::Tree>. It also handles L</trace> route memoization 
and uniqueness-checking.

=head2 new

  my $net = IRC::Server::Tree::Network->new;

  ## With named opts:
  my $net = IRC::Server::Tree::Network->new(
    tree    => $my_tree,

    ## Turn off route preservation:
    memoize => 0,
  );

  ## With an existing Tree and no other opts:
  my $net = IRC::Server::Tree::Network->new(
    IRC::Server::Tree->new( $previous_tree )
  );

The constructor initializes a fresh Network.

=head3 memoize

Setting 'memoize' to a false value at construction time will disable 
route preservation, saving some memory at the expense of more frequent 
tree searches.

=head3 tree

If an existing Tree is passed in, a list of unique node names in the Tree 
is compiled and validated.

Routes are not stored until a L</trace> is called.

=head2 add_peer_to_self

  $net->add_peer_to_self( $peer_name );

Adds a node identified by the specified peer name to the top level of our 
tree; i.e., a directly-linked peer.

The identifier must be unique. IRC networks may not have duplicate 
entries in the tree.

You can optionally specify an existing tree of nodes to add under the new 
node as an ARRAY:

  $net->add_peer_to_self( $peer_name, $array_ref );

...but it will trigger a tree-walk to reset seen peers.

=head2 add_peer_to_name

  $net->add_peer_to_name( $parent_name, $new_peer_name );

Add a node identified by the specified C<$new_peer_name> to the specified 
C<$parent_name>.

Returns empty list and warns if the specified parent is not found.

Specifying an existing ARRAY of nodes works the same as 
L</add_peer_to_self>.

=head2 have_peer

  if ( $net->have_peer( $peer_name ) ) {
    . . .
  }

Returns a boolean value indicating whether or not the specified name is 
already seen in the tree. (This relies on our tracked entries, rather 
than finding a path for each call.)

=head2 hop_count

  my $count = $net->hop_count;

Returns the number of hops to the destination node; i.e., a 
directly-linked peer is 1 hop away:

  hubA
    leafA     - 1 hop
    hubB      - 1 hop
      leafB   - 2 hops

=head2 split_peer

  my $split_names = $net->split_peer( $peer_name );

Splits a node from the tree.

Returns an ARRAY containing the names of every node beneath the one that 
was split, not including the originally specified peer.

=head2 trace

  my $trace_names = $net->trace( $peer_name );

Returns the same value as L<IRC::Server::Tree/trace>; see the 
documentation for L<IRC::Server::Tree> for details.

This proxy method memoizes routes for future lookups. They are cleared 
when L</split_peer> is called.

=head2 tree

The C<tree()> method returns the L<IRC::Server::Tree> object belonging to 
this Network.

  my $as_hash = $net->tree->as_hash;

See the L<IRC::Server::Tree> documentation for details.

Note that calling methods on the Tree object that manipulate the tree 
(adding and deleting nodes) will break future lookups via Network. Don't 
do that; if you need to manipulate the Tree directly, fetch it, change 
it, and create a new Network:

  my $tree = $net->tree;

  ## ... call methods on the IRC::Server::Tree ...
  $tree->del_node_by_name('SomeNode');

  my $new_net = IRC::Server::Tree::Network->new(
    $tree
  );

... or if you must, at least call reset_tree to reset our state and 
validate the tree:

  $net->tree->del_node_by_name('SomeNode');
  $net->reset_tree;

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
