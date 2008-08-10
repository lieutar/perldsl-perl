use strict;
use warnings;
use Test::More tests => 1;

package t::00;
use base qw( PerlDSL::Subs );
use Cwd qw( getcwd );

sub _include { ('getcwd'); }

sub _exclude{
  my ($self, $name, $code) = @_;
  return 1 if $self->SUPER::_exclude($name, $code);
  return 1 if $name eq 'hoge';
  0;
}

sub hoge{
  # dummy
}

do{
  my $name = $_;
  my $sub  = sub{ $name . ":". shift->{-name} };
  no strict 'refs';
  *{$name} = $sub;
} foreach qw( foo bar bazz);


TODO: {
  my $msg = undef;

  my %env = __PACKAGE__->subs;
  foreach my $sym (qw(getcwd foo bar bazz)){
    next if delete $env{$sym};
    $msg = ($msg ? $msg."\n" : "")."'$sym' was not retrived.";
  }

  $msg = sprintf("extra symbol was retrived. (%s)",
                 (join ", ", keys %env)) if !$msg  && %env ;
  package main;
  if(defined $msg){
    diag($msg);
    ok(0);
  }
  else {
    ok(1);
  }
}

