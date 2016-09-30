use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'App::SourceCodeStats',
    license           => 'perl',
    dist_author       => 'Ivan Wills <ivan.wills@gmail.com>',
    dist_version_from => 'lib/App/SourceCodeStats.pm',
    requires          => {
        'perl'                 => '5.006',
        'File::TypeCategories' => 0,
        'File::chdir'          => '0.1008',
        'List::MoreUtils'      => '0.33',
        'Moose'                => '2.1402',
        'Path::Tiny'           => 0,
        'Tk'                   => '804.031',
        'Tk::widgets'          => '4.005',
        'YAML'                 => '1.13',
        'namespace::autoclean' => '0.22',
        'version'              => '0.9902',
    },
    build_requires => {
        'Test::More'     => '0.88',
        'Test::Warnings' => 0,
    },
    add_to_cleanup     => [ 'App-SourceCodeStats-*' ],
    create_license     => 1,
    meta_merge => {
        resources => {
            repository => 'git://github.com/ivanwills/App-SourceCodeStats.git',
            bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::SourceCodeStats',
        },
    },
);

$builder->create_build_script();
