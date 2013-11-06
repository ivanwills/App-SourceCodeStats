use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name       => 'App::SourceCodeStats',
	license           => 'perl',
	dist_author       => 'Ivan Wills <ivan.wills@gmail.com>',
	dist_version_from => 'lib/App/SourceCodeStats.pm',
	requires          => {
		'perl'             => 5.008,
	},
	build_requires => {
		'Test::More'       => 0,
		'Test::NoWarnings' => 0,
	},
	add_to_cleanup     => [ 'App-SourceCodeStats-*' ],
	create_makefile_pl => 'traditional',
	create_license     => 1,
	meta_merge => {
		resources => {
			repository => 'git://github.com/ivanwills/App-SourceCodeStats.git',
			bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::SourceCodeStats',
		},
	},
);

$builder->create_build_script();
