#!perl -T
use strict;
use warnings;
use PerlDSL::Perl qw( runscript );
use File::Path qw( rmtree );
use Test::More 'no_plan';

BEGIN{
  sub die_like (&$;$){
    my $block = shift;
    my $regex = shift;
    if( eval{ $block->() ; 1 } ) {
      &fail(@_);
    }
    else {
      &like( $@, $regex, @_ );
    }
  }
}



is( runscript( 'foo', foo => sub{123} ), 123);
is( runscript('t/rsc/00.pl' , foo => sub{456}), 456 );
{
  my %hoge;
  runscript('

$foo = 123

', '$foo' => \$hoge{foo});
  is( $hoge{foo} , 123);
}

die_like{
  runscript('print 123', -deny => ['print']);
} qr{'print' trapped by operation mask};

