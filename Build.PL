#!/usr/bin/env perl
use Module::Build;
use strict; use warnings FATAL => 'all';

my $build = Module::Build->new(
  module_name => 'IRC::Server::Tree',
  license     => 'perl',
  dist_abstract => 'Represent and manipulate an IRC network tree',
  dist_author   => 'Jon Portnoy <avenj@cobaltirc.org>',
  recursive_test_files => 1,
  create_readme => 1,
  create_makefile_pl => 'small',
  configure_requires => {
    'Module::Build' => '0.40',
  },
  build_requires => {
    'Test::More' => 0,
  },
  requires => {
    'perl'         => '5.10.1',
    'Carp'         => 0,
    'Storable'     => 0,
    'Scalar::Util' => 0,

    'strictures'   => 1,
  },
);

$build->create_build_script;

__END__

