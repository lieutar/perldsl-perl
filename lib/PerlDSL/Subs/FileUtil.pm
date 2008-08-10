
use strict;
use warnings;

package PerlDSL::Subs::FileUtil;

=head1 NAME

PerlDSL::Subs::FileUtil - Provides functions for specificate files for configuration files.

=head1 DESCRIPTION



=cut

our $VERSION = 0.01;

use Path::Class qw( !file !dir );
use File::Path qw( mkpath );
use File::HomeDir;
use base qw( PerlDSL::Subs );
use Carp;



=head1 STATIC METHODS

=over 4

=item C<new>



=cut

sub new {
  my $self = shift;
  my %opt = @_;
  my $umask = exists($opt{umask}) ? delete($opt{umask}) : umask;
  $self->SUPER::new( filemode => ($umask ^ 0666) ,
                     dirmode  => ($umask ^ 0777) ,
                     %opt );
}


=item C<ops>

Returns necessarly opmasks to work functions in this module.

=cut

sub ops{
  (':filesys_read', ':filesys_write', ':filesys_open');
}

sub _filter {
  my @args = @_;
  my @ret = ();
  foreach my $part (@args){
    $part =~ s#([/\\]|\A)~([^\\/]*)#
      $1 . ($2 ? File::HomeDir->users_home($2) : File::HomeDir->my_home())
        #gex;
    push @ret, $part;
  }
  @ret;
}


=back

=head1 DIRECTIVES

=over 4

=item C<dir>

  $CONFIGDIR = dir("~/.my-app");

Specifies readable directory and returns its Path::Class::Dir object.

=cut

sub dir{
  my $self = shift;
  my $f = Path::Class::dir( _filter @_ );
  croak "directory \"$f\" is not exists"      unless -e $f;
  croak "directory \"$f\" is not a directory" unless -d $f;
  croak "directory \"$f\" is not executable"  unless -x $f;
  croak "directory \"$f\" is not readable"    unless -r $f;
  $f;
}


=item C<DIR>

  $CACHEDIR = DIR("~/.my-app/cache");

Specifies writable drectory and returns its Path::Class::Dir object.
If the directory is not exists, this creates the directory.

=cut

sub DIR{
  my $self = shift;
  my $f = Path::Class::dir( _filter @_ )->absolute;
  if ( -e $f ){
    croak "directory \"$f\" is not a directory" unless -d $f;
    croak "directory \"$f\" is not executable"  unless -x $f;
    croak "directory \"$f\" is not readable"    unless -r $f;
    croak "directory \"$f\" is not writable"    unless -w $f;
  }
  else {
    mkpath( $f => { mode => $self->{dirmode} } );
  }
  $f;
}


=item C<file>

  $SIGNATURE = file("~/.signature");

=cut

sub file{
  my $self = shift;
  my $f = Path::Class::file( _filter @_ )->absolute;
  croak "file \"$f\" is not exists"   unless -e $f;
  croak "file \"$f\" is a directory"  if     -d $f;
  croak "file \"$f\" is not readable" unless -r $f;
  $f;
}


=item C<FILE>

  $PIDFILE = FILE("~/local/var/run/my-app.pid");

=cut

sub FILE{
  my $self = shift;
  my $f = Path::Class::file( _filter @_ )->absolute;
  if ( -e $f ){
    croak "file \"$f\" is a directory"  if -d $f;
    croak "file \"$f\" is not readable" unless -r $f;
    croak "file \"$f\" is not writable" unless -w $f;
  }
  else {
    mkpath( $f->parent => { mode => $self->{dirmode} } );
    $f->touch;
    chmod( $self->{filemode} , $f );
  }
  $f;
}

1;
__END__

=back

=head1 AUTHOR

lieutar, C<< <lieutar at 1dk.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-perldsl-runner at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PerlDSL-Subs-FileUtil>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

and...

Even if I am writing strange English because I am not good at English, 
I'll not often notice the matter. (Unfortunately, these cases aren't
testable automatically.)

If you find strange things, please tell me the matter.


=head1 COPYRIGHT & LICENSE

Copyright 2008 lieutar, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
