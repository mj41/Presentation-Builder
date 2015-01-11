#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin ();
use File::Slurp ();

use_ok('Presentation::Builder::SlideCollection::Reveal');

my $sc = Presentation::Builder::SlideCollection::Reveal->new(
	title => 'test-title',
	subtitle => 'test-subtitle',
	author => 'test-author',
	author_url => 'http://test.url',
	date => 'test-date',
	'description' => 'test-description',
	revealjs_dir => File::Spec->catdir( $FindBin::RealBin, '..', 'temp', 'third-part', 'reveal.js' ),
	out_fpath => File::Spec->catfile( $FindBin::RealBin, '..', 'temp', 'test-final-slides', 'index.html' ),
	vl => 1, # verbose level
);

use_ok('Presentation::Builder::RunEnv');

my $run_env = Presentation::Builder::RunEnv->new(
	reset_env => sub {},
	init_env => sub {},
);

$sc->add_slide(
	'Git',
	markdown => <<'MD_END',
* slide item 1
* slide item 2
MD_END
	notes => <<'MD_NOTES',
* notes item 1
* notes item 2
MD_NOTES
);

$sc->run_all( $run_env );
my $out_fpath = $sc->out_fpath;

undef $sc;
undef $run_env;

my $out_html = File::Slurp::read_file( $out_fpath );

ok( $out_html =~ m{test-title}s, 'test-title found' );
ok( $out_html =~ m{slide item 1}, 'slide item 1 found' );

done_testing;
