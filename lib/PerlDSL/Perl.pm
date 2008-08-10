package PerlDSL::Perl;

use warnings;
use strict;
use Time::HiRes;
use Path::Class;
use Sub::Name;
use Safe;
use Safe::Hole;
use Carp;

=head1 NAME

PerlDSL::Perl - Provides easy way to run perl script as DSL.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use PerlDSL::Perl qw( runscript );
    my $Cfg;
    runscript( 'path/to/script',
               -prepend    => 'use fooFilter;',
               -untaint    => 1,
               '$MAILADDR' => \$Cfg->{'MAILADDR'},
               '$PASSWORD' => \$Cfg->{'PASSWORD'},
               foo         => sub{ print "foo called" },
               bar         => sub{ print "bar called" },
             );

=head1 DESCRIPTION

PerlDSL::Perl provides easy way to build running environment of 
Perl script as DSL.

Generally these ways of DSL need to export symbols.
In addition, they need to run scripts under safety environment.
Moreover, they need to raise errors with appropriate line number informations.

This module will remove these messy stuffs from our gentle source code.

=head1 EXPORT

PerlDSL::Perl has no tags for exportation.
But any functions are exportable.

=head1 FUNCTIONS

=over 4

=cut

use Sub::Exporter
  -setup => { exports => [ qw(genscript compilescript runscript) ] };

{
  my $count = 0;
  sub _gensym {
    join ( "_",
           map {
             sprintf( '%X',$_ )
           }( $$,
              Time::HiRes::gettimeofday() ,
              int ( 0xFFFFFFFF *  rand ),
              $count++ ) );
  }
}

sub _prepare_args{
  my %arg;
  if(@_ % 2){
    my $head = shift;
    %arg = @_;
    if ( $head !~ /[\x0d\x0a]/ &&  -f $head ){
      $arg{-file} = $head;
    }
    else {
      $arg{-src} = $head;
    }
  }
  else {
    %arg = @_;
  }
  %arg;
}

=item C<genscript>

  my ( $pkg, $script ) =
    genscript( $file ,
               -prepend => 'subname( "my dsl" => sub{'
               -append  => '})',
               foo => sub:lvalue{ $FOO } );

Generates a runtime script code from received arguments,
It returns a package of the script, and the runtime script in array context.
In scalar context, it returns only runtime script.

=cut

sub genscript {

  my %opt = _prepare_args(@_);
  my $body;
  my $file = undef;

  my $untaint =
    ( UNIVERSAL::isa($opt{-untaint}, 'CODE') ? $opt{-untaint} :
      UNIVERSAL::isa($opt{-untaint}, 'Regexp') ? do{
        my $regex = $opt{-untaint};
        sub{ /($regex)/s; $1 }
      } : sub{ /\A(.*)/s; $1} );
  delete $opt{-untaint};

  if( exists $opt{-file}){
    $file = Path::Class::file(delete $opt{-file})->absolute;
    local $_ = join( "", $file->slurp);
    $body = sprintf("#line 1 %s\n%s",
                    $file ,
                    $untaint->($_));
  }
  elsif ( exists $opt{-src}){
    local $_ = delete $opt{-src};
    $body = "#line 1 option(-src)\n". $untaint->($opt{-file});
  }
  else {
    confess "genscript needs option '-file' or '-src'.";
  }

  my $prepend = "";
  if( exists $opt{-prepend} ){
    $prepend = "#line 1 option(-prepend)", delete($opt{-prepend});
  }

  my $append = "";
  if( exists $opt{-append} ) {
    $append = "#line 1 oprion(-append)", delete($opt{-append});
  }

  my $pkg = __PACKAGE__ . "::_script_". _gensym;
  my $var = "_tmp_". _gensym;
  my $src = sprintf( join( "\n",
                           'package %s;',
                           'use strict;',
                           'use warnings;',
                           'use Carp;',
                           'do{ my $%s = sub{',
                           '%s',
                           '%s',
                           '%s',
                           '}; $%s };' ),
                     $pkg ,
                     $var,
                     $prepend,
                     $body,
                     $append,
                     $var);

  wantarray ? ( $pkg , $src ) : $src;
}

=item C<compilescript>

  my $code = compilescript( $file ,
                           -prepend => 'subname( "my dsl" => sub{'
                           -deny    => ':all',
                           -permit  => [':browse'],
                           -append  => '})',
                           foo      => sub:lvalue{ $FOO },
                           '$bar'   => \$Cfg{'bar'} );

  ## or

  my $code = compilescript(-file    => $file ,
                           -prepend => 'subname( "my dsl" => sub{'
                           -deny    => ':all',
                           -permit  => [':browse'],
                           -append  => '})',
                           foo      => sub:lvalue{ $FOO },
                           '$bar'   => \$Cfg{'bar'} );


  ## or

  my $code = compilescript( q{
      $bar = 123;
      foo = 'foo';
  } ,
                           -prepend => 'subname( "my dsl" => sub{'
                           -deny    => ':all',
                           -permit  => [':browse'],
                           -append  => '})',
                           foo      => sub:lvalue{ $FOO },
                           '$bar'   => \$Cfg{'bar'} );

  ## or

  my $code = compilescript( -src    => q{
      $bar = 123;
      foo = 'foo';
  } ,
                           -prepend => 'subname( "my dsl" => sub{'
                           -deny    => ':all',
                           -permit  => [':browse'],
                           -append  => '})',
                           foo      => sub:lvalue{ $FOO },
                           '$bar'   => \$Cfg{'bar'} );


Makes a script to compiled code reference.
This receives common options (describes later) and symbols with
its references.

=cut

sub _modify_safe {
  my ($cpt, $hole, %gen) = @_;

  if($gen{-deny}) {
    $cpt->deny(UNIVERSAL::isa($gen{-deny},'ARRAY')
               ? @{$gen{-deny}} : $gen{-deny});
  }

  $gen{-permit} = $gen{-allow} if($gen{-allow});
  if($gen{-permit}) {
    $cpt->permit(UNIVERSAL::isa($gen{-permit},'ARRAY')
                 ? @{$gen{-permit}} : $gen{-permit});
  }


  if($gen{-share_from}) {
    foreach my $a (@{$gen{-share_from}}){
      $cpt->share_from( UNIVERSAL::isa( $a, 'ARRAY' ) ? $a : [$a] );
    }
  }

  $cpt->permit('require','caller','entereval', 'padany');
}

sub  compilescript {

  my %arg = _prepare_args(@_);
  my %gen = ();
  my %env = ();

  foreach my $key ( keys %arg ){
    if ( $key =~ /^-/ ) {
      $gen{$key} = $arg{$key};
    }
    else {
      $env{$key} = $arg{$key};
    }
  }

  my ($pkg, $script ) = genscript( %gen );

  my $no_safe = $gen{-no_safe};
  my ($cpt, $hole);

  unless($no_safe){
    $cpt = Safe->new( $pkg );
    $hole = Safe::Hole->new;
    _modify_safe($cpt, $hole, %gen);
  }

  while( my ($sym, $ref) = each %env ) {

    if( $sym =~ s/\A\$// ){
      $ref = defined($ref) ? $ref : do{ my $a = undef; \$a };
      confess "illegal type was received as reference of \$$sym"
        unless UNIVERSAL::isa( $ref, 'SCALAR' );
    }
    elsif( $sym =~ s/\A\@//){
      $ref = defined($ref) ? $ref : [];
      confess "illegal type was received as reference of \@$sym"
        unless UNIVERSAL::isa( $ref, 'ARRAY' );
    }
    elsif( $sym =~ s/\A\%//){
      $ref = defined($ref) ? $ref : {};
      confess "illegal type was received as reference of \%$sym"
        unless UNIVERSAL::isa( $ref, 'HASH' );
    }
    else{
      $sym =~ s/\A\&//;
      confess "illegal type was received as reference of \&$sym"
        unless UNIVERSAL::isa( $ref, 'CODE' );
      # $ref = subname( $sym => $ref );
      my $glob = do{ no strict 'refs'; \*{"${pkg}::$sym"} };
      *{$glob} = $ref;
      unless ($no_safe) {
        my $share = '&'. $pkg . '::'. $sym;
        $hole->wrap( $ref , $cpt, $share );
      }
      next;
    }

    my $glob = do{ no strict 'refs';
                   ( $no_safe
                     ? \*{"${pkg}::$sym"}
                     :   \*{"${pkg}::${pkg}::$sym"} )};
    *{$glob} = $ref;
  }

  # local $SIG{__WARN__} = sub{ croak shift };
  my $code = $no_safe ? (eval $script ) :  $cpt->reval( $script );;

  if( $@ ){
    my $err = sprintf( "Caught below errors when compilation:\n%s",
                       $@);

    unless( $arg{-file} ) {
      my $sample = $script;
      my $n = 1;
      $sample =~ s/^/
        my $line = $';
        sprintf('#% 3d:', ($line =~ m@^#line\s(\d+)@ ? ($n = $1) - 1 : $n++))
      /meg;
      $err .= "\nSrc:\n$sample\n";
      $err .= "\nIf '$arg{-src}' is a filename, that file is not exists.\n\n"
        unless $arg{-src} =~ /[\x0d\x0a]/;
    }

    die $err;
  }
  $code;
}

=item C<runscript>

  my $retval = runscript( $file ,
                          -prepend => 'subname( "my dsl" => sub{'
                          -deny    => ':all',
                          -permit  => [':browse'],
                          -append  => '})',
                          foo => sub:lvalue{ $FOO } );

Runs script and returns the return value of the script.

=cut

sub runscript {

  my $code = compilescript( @_ );
  my @R = ();

  if( wantarray ){
    eval { @R = $code->() };
  }
  else {
    eval { $R[0] = $code->() };
  }

  die $@ if $@;
  wantarray ? @R : $R[0];
}


1; # End of PerlDSL::Perl

__END__

=back

=head1 COMMON OPTIONS

=over 4

=item C<-src>

Specifies a source of a script,

=item C<-file>

Specifies a path to script source file.

=item C<-prepend> C<-append>

If these options are provided, the script will be surrounded by these values.

=item C<-permit>  C<-deny>

Sets opmask to the compilers C<Safe> compartment.

=item C<-untaint>

This module untaints scripts forcely, and the way of untainting is somewhat
assertive. (It is only do "/^(.*)/;$_=$1").

If the option is provided, the untainting is follows that option value.
The value of the option is Regex reference or CODE reference. If a value
is a CODE reference , untainter is provides script source code to $_, and
receives return value of that CODE reference.

=back

=head1 SECURITY

This module uses Safe compartment. However security of this solution is
not enough to public interface. (e.g. http://codepad.org ).
Alternatively, values from script don't have taint marks.

=head1 AUTHOR

lieutar, C<< <lieutar at 1dk.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-perldsl-runner at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PerlDSL-Perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2008 lieutar, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


