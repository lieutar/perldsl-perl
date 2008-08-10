
use strict;
use warnings;
package PerlDSL::Subs;

BEGIN{
  require PerlDSL::Perl;
  our $VERSION = $PerlDSL::Perl::VERSION;
}

=head1 NAME

PerlDSL::Subs - Base package of PerlDSL subroutine package.

=head1 VERSION

0.01

=cut

our $VERSION='0.01';

=head1 SYNOPSYS

  package PerlDSL::Subs::Foo;

  use base qw( PerlDSL::Subs );
  use Carp;

  sub new {
     my $self = shift;
     my %args = @_;
     confess "'foo' is not specified" unless exists $args{-foo};
     $self->SUPER::new(%args);
  }
  
  sub ops { qw( print ) }
  
  sub foo:lvalue{
    my $self = shift;
    $self->{-foo};
  }
  
  sub bar{
    my $self = shift;
    print ( $self->{foo} . " bar" );
  }
  
  package My::Application;
  use PerlDSL::Perl qw( runscript );
  
  runscript( $scriptfile,
             -deny  => [':all'],
             -allow => [ PerlDSL::Subs::Foo->ops ],
             PerlDSL::Subs::Foo->subs( -foo => 1 ) )


=head1 DESCRIPTION

PerlDSL::Subs provides simple framework for subroutine package of PerlDSL.

Applications of this framework is 

=cut

use Scalar::Util qw( blessed);
use B;
use Carp;
use Sub::Exporter;

sub import {
  my $self = shift;
  return unless @_;
  my $constarg =  UNIVERSAL::isa( $_[0], 'ARRAY' ) ? shift : [];
  my %subs = $self->subs( @$constarg );
  my %exports = ();
  while( my( $name => $sub ) = each %subs ){
    $exports{$name} = sub{ $sub };
  }
  my $exporter = Sub::Exporter::build_exporter({ exports => \%exports, } );
  unshift @_, $_;
  goto $exporter;
}

=head1 METHODS

=over 4

=item C<new>

=cut

sub new{
  my $self = shift;
  my $pkg  = blessed( $self ) || $self;
  confess __PACKAGE__." is abstract class" if $pkg eq __PACKAGE__;
  bless { @_ }, $pkg;
}



=item C<subs>

Returns subroutine references and its

=cut

sub subs{
  my $self = shift;
  $self = $self->new( @_ ) unless blessed $self;
  map {
    my $meth = $_;
    ( $meth => sub{ $self->$meth(@_) } )
  } ( $self->_exports );
}



=item C<ops>

Returns necessarly opmasks to use to functions in the module.
Subclass overwrides it.

=cut

sub ops {
  ();
}

sub _exports {
  my $self  = shift;
  my $pkg   = blessed ( $self ) || shift;
  my %stash = do{ no strict; %{"${pkg}::"} };
  my @ret   = ();
  while( my ($sym, $glob) = each %stash ) {
    next unless my $code = *{$glob}{CODE};
    next if $self->_exclude($sym , $code);
    push @ret , $sym;
  }
  ( @ret, $self->_include );
}



=item C<_include>

  sub _include {
    my $self = shift;
  }


=cut

sub _include { () }



=item C<_exclude>

  sub _exclude {
    my $self = shift;
    ( $self->SUPER::exclude, qw( my private functions ) );
  }

Subclass overwrides , if needs to specify exclude symbols.

=cut

sub _exclude {
  my $self = shift;
  my $sym  = shift;
  my $code = shift;
  return 1 if $sym =~ /\A(?:
                         _.*|
                         new|
                         subs|
                         ops|
                         AUTOLOAD|
                         BEGIN|
                         END|
                         DESTROY|
                         import
                       )\Z/x;
  my $pkg  = blessed( $self ) || $self;
  B::svref_2object($code)->STASH->NAME ne $pkg;
}

1;
__END__


=back

=head1 SEE ALSO

=over 4

=item C<PerlDSL::Perl>

=back

=cut
