#!perl

use strict;
use warnings;

use Dist::Zilla     1.093250;
use Dist::Zilla::Tester;
use File::Temp qw{ tempdir };
use Git::Wrapper;
use Path::Class;
use Test::More      tests => 8;
use Test::Exception;

# Mock HOME to avoid ~/.gitexcludes from causing problems
$ENV{HOME} = tempdir( CLEANUP => 1 );

# build fake repository
my $zilla = Dist::Zilla::Tester->from_config({
  dist_root => dir('corpus/check-nonfatal')->absolute,
});

chdir $zilla->tempdir->subdir('source');
system "git init";
my $git   = Git::Wrapper->new('.');
$git->config( 'user.name'  => 'dzp-git test' );
$git->config( 'user.email' => 'dzp-git@test' );

# create initial .gitignore
# we cannot ship it in the dist, since PruneCruft plugin would trim it
append_to_file('.gitignore', 'Foo-*');
$git->add( { force => 1 }, '.gitignore');
$git->commit( { message=>'ignore file for git' } );

# untracked files
$zilla->logger->logger->clear_events;
lives_ok { $zilla->release } 'nonfatal untracked files';
like(join("\n", map { $_->{message} } @{ $zilla->logger->logger->events }),
     qr/untracked files/,
     'nonfatal untracked files');

# index not clean
$zilla->logger->logger->clear_events;
$git->add( qw{ dist.ini Changes foobar } );
lives_ok { $zilla->release } 'nonfatal index not clean';
like(join("\n", map { $_->{message} } @{ $zilla->logger->logger->events }),
     qr/some changes staged/,
     'nonfatal index not clean');
$git->commit( { message => 'initial commit' } );

# modified files
$zilla->logger->logger->clear_events;
append_to_file('foobar', 'Foo-*');
lives_ok { $zilla->release } 'nonfatal uncommitted files';
like(join("\n", map { $_->{message} } @{ $zilla->logger->logger->events }),
     qr/uncommitted files/,
     'nonfatal uncommitted files');
$git->checkout( 'foobar' );

$zilla->logger->logger->clear_events;
lives_ok { $zilla->release } 'releases fine normally';
like(join("\n", map { $_->{message} } @{ $zilla->logger->logger->events }),
     qr/in a clean state/,
     'clean');

sub append_to_file {
    my ($file, @lines) = @_;
    open my $fh, '>>', $file or die "can't open $file: $!";
    print $fh @lines;
    close $fh;
}
