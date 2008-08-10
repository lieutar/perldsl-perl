use inc::Module::Install;

name     'PerlDSL-Perl';
all_from 'lib/PerlDSL/Perl.pm';
author   'lieutar <lieutar@1dk.jp>';

requires 'Scalar::Util';
requires 'Path::Class';
requires 'File::Path';
requires 'Sub::Name';
requires 'B';
requires 'Carp';
requires 'Time::HiRes';
build_requires 'Test::More';

auto_install;

WriteAll;

