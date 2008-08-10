
use strict;
use warnings;
use PerlDSL::Perl qw( runscript );
use File::Path qw( rmtree );

our $TMPDIR;
BEGIN{
  use Test::More;
  $TMPDIR = "t/rsc/tmp";
  mkdir $TMPDIR;
  plan 'no_plan';
}

END{
  rmtree( $TMPDIR ) if defined $TMPDIR;
}


require PerlDSL::Subs::FileUtil;

isa_ok(runscript("dir '${TMPDIR}'",
                 -permit => [ PerlDSL::Subs::FileUtil->ops ],
                 PerlDSL::Subs::FileUtil->subs),
       'Path::Class::Dir');
{
  my $newdir = "${TMPDIR}/foo/bar/bazz";
  ok( ! -d $newdir );
  isa_ok(runscript("DIR '$newdir'",
                   -permit => [ PerlDSL::Subs::FileUtil->ops ],
                   PerlDSL::Subs::FileUtil->subs),
         'Path::Class::Dir');
  ok( -d $newdir );
}

isa_ok(runscript('file "'. __FILE__ .'"',
                 -permit => [ PerlDSL::Subs::FileUtil->ops ],
                 PerlDSL::Subs::FileUtil->subs),
      'Path::Class::File');

{
  my $newfile = "${TMPDIR}/hoge/fuga/123";

  isa_ok(runscript("FILE '$newfile'",
                   -permit => [ PerlDSL::Subs::FileUtil->ops ],
                   PerlDSL::Subs::FileUtil->subs),
         'Path::Class::File' );

  ok( -f $newfile );
}


