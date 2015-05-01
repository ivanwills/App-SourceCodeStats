#!/usr/bin/env perl

# Created on: 2008-05-23 11:17:39
# Create by:  ivanw
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use strict;
use warnings;
use version;
use List::MoreUtils qw/uniq/;
use Getopt::Long;
use Pod::Usage;
use English qw/ -no_match_vars /;
use FindBin qw/$Bin/;

use File::chdir;
use File::Path;
use File::Find;
use File::Spec::Functions;
use Tk;
use Tk ':eventtypes';
use Tk::widgets qw/Toplevel LabEntry HList DialogBox NoteBook/;
use YAML qw/LoadFile DumpFile/;
use Ivan::Api;

our $VERSION = version->new('0.0.1');
my ($name)   = $PROGRAM_NAME =~ m{^.*/(.*?)([.].*?)?$}mxs;

my %widget;
my $settings;
my %option = (
    config   => undef,
    nogeom   => 0,
    simplify => 0,
    total    => 0,
    verbose  => 0,
    doxygen  => -f '/usr/bin/doxygen' ? '/usr/bin/doxygen' : 'C:/Program Files/Doxygen/Doxygen.exe',
    man      => 0,
    help     => 0,
    VERSION  => 0,
);

main();
exit 0;

sub main {

    Getopt::Long::Configure('bundling');
    GetOptions(
        \%option,
        'add|a=s@',
        'config|conf|c=s',
        'nogeom|ng!',
        'simplify|s!',
        'list|l',
        'test|t',
        'verbose|v+',
        'man',
        'help',
        'VERSION!',
    ) or pod2usage(2);

    if ( $option{'VERSION'} ) { ## no critic
        print "$name Version = $VERSION\n";
        exit 1;
    }
    elsif ( $option{'man'} ) {
        pod2usage( -verbose => 2 );
    }
    elsif ( $option{'help'} ) {
        pod2usage( -verbose => 1 );
    }
    elsif ( $option{'list'} ) {
        list();
        return;
    }

    # do stuff here
    if ( !-d catfile( $ENV{HOME}, ".$name" ) ) {
        mkpath( catfile( $ENV{HOME}, ".$name" ) );
    }

    if ( !$option{'config'} ) {
        $option{'config'} = catfile( $ENV{HOME}, ".$name", 'default.yml' );
    }
    elsif ( !-f $option{'config'} && $option{'config'} =~ /^\w+$/xms ) {
        $option{'config'} = catfile( $ENV{HOME}, ".$name", "$option{'config'}.yml" );
    }
    $settings = -f $option{'config'} ? LoadFile( $option{'config'} ) : {};

    if ( $option{add} ) {
        push @{ $settings->{directories}{paths} }, @{ $option{add} };
    }

    open_window();
    MainLoop;

    DumpFile( $option{config}, $settings );

    return;
}

sub list {

    opendir my $dir, catfile( $ENV{HOME}, ".$name" );
    my @files = grep { $_ ne q{.} && $_ ne q{..} } readdir $dir;
    closedir $dir;

    FILE:
    for my $file ( sort @files ) {
        next FILE if $file !~ /[.]yml$/xms;
        $file =~ s/[.]yml//xms;

        print "$file\n";
    }

    return;
}

sub open_window {
    $widget{mw} = new MainWindow( -title => $name );
    $widget{mw}->configure( -menu => $widget{mw}->Menu( -menuitems => menubar_etal() ) );

    $widget{toolbar} = $widget{mw}->Frame( -borderwidth => 3, -relief => 'groove' )->pack( -side => 'top', -fill => 'x', -expand => 0 );
    $widget{exit_button}    = $widget{toolbar}->Button( -text => 'E X I T',       -command => \&exit_scs       )->pack( -side => 'left' );
    $widget{new_button}     = $widget{toolbar}->Button( -text => 'N E W',         -command => \&new_stats_path )->pack( -side => 'left' );
    $widget{refresh_button} = $widget{toolbar}->Button( -text => 'R E F R E S H', -command => \&refresh_scs    )->pack( -side => 'left' );

    $widget{notebook} = $widget{mw}->NoteBook( -font => 'Monospace 10 bold' )->pack( -side => 'right', -fill => 'both', -expand => 1 );

    if ( $option{nogeom} || !$settings->{window}{geometry} ) {
        $settings->{window}{geometry} = '420x460+400+100';
    }

    $widget{mw}->geometry( $settings->{window}{geometry} );
    $widget{mw}->bind( '<Destroy>', \&exit_scs );
    scan_directories();

    return;
}

sub scan_directories {
    my @columns = (
        { label => 'File Type',    name => q{} },
        { label => 'Files',        name => 'files' },
        { label => 'Lines',        name => 'lines' },
        { label => 'Blank Lines',  name => 'blank' },
        { label => 'Simple Lines', name => 'simple' },
        { label => 'Comments',     name => 'comment' },
        { label => 'Bytes',        name => 'bytes' },
        { label => 'Net Lines',    name => 'net' },
    );
    my $paths = $settings->{directories}{paths} ||= [];

    # Loop over each recorded path
    PATH:
    for my $path ( uniq @{$paths} ) {
        next PATH if !-d $path;
        my ($label) = $path =~ m{ / ( [^/]* ) /? $}xms;

        $widget{pages}{$path}{book}     = $widget{notebook}->add( $path, -label => $label );
        $widget{pages}{$path}{scrolled} = $widget{pages}{$path}{book}->Scrolled(
            'HList',
            -scrollbars => 'osoe',
            -columns    => ( scalar @columns ),
            -header     => 1,
            -selectmode => 'single'
        )->pack( -side => 'bottom', -fill => 'both', -expand => '1' );

        $widget{pages}{$path}{list} = $widget{pages}{$path}{scrolled}->Subwidget();
        for my $col ( 0 .. @columns - 1 ) {
            $widget{pages}{$path}{list}->headerCreate( $col, -text => $columns[$col]{label} );
        }

        $widget{pages}{$path}{directory} = $path;
        $widget{pages}{$path}{Directory} = $widget{pages}{$path}{book}->LabEntry(
            -label        => 'Directory:',
            -textvariable => \$widget{pages}{$path}{directory},
            -labelPack    => [ -side => 'left' ]
        )->pack( -side => 'left', -fill => 'x', -expand => '1' );
        $widget{pages}{$path}{Doxygen}
            = $widget{pages}{$path}{book}->Button( -text => 'Doxygen', -command => [ \&doxygenate, $path ] )
            ->pack( -side => 'right', -padx => '3' );

        my %stats;
        find(
            sub {
                return if -l $File::Find::name
                    || -d $File::Find::name
                    || $File::Find::name =~ m{
                        /
                        (?:_build|[.]prove|cover_db|_build|blib|.*META[.](?:json|yml)|[.]git|[.]bzr|[.]svn|CVS|errors.err|tags|cmds)
                        (?: / | $ )
                    }xms;
                return if /(~|old|.sw[ponx])$/;
                return if $File::Find::name =~ m{ blib }xms;

                my %fstats = Ivan::Api::get_file_stats( $File::Find::name, $option{simplify} );
                for my $type ( keys %fstats ) {
                    for my $stat ( keys %{ $fstats{$type} } ) {
                        $stats{$type}{$stat} += $fstats{$type}{$stat};
                    }
                    $stats{$type}{files}++;
                }
            },
            $path,
        );
        if ( $option{verbose} || $option{test} ) {
            print "$path\n";
            for my $col ( 0 .. $#columns - 1) {
                print "$columns[$col]{name}\t";
            }
            print "\n";
            for my $type (sort keys %stats) {
                print "$type\t";
                for my $col ( 1 .. $#columns - 1) {
                    print comma($stats{$type}{ $columns[$col]{name} }) . "\t";
                }
                print "\n";
            }
            $option{total} += $stats{perl}{lines} || 0;
            $option{net}   += $stats{perl}{lines} || 0;
            for my $col ( 3 .. $#columns - 2 ) {
                $option{net} -= $stats{perl}{ $columns[$col]{name} } || 0;
            }
        }
        $option{total} ||= 0;
        $option{net}   ||= 0;
        print "Total = $option{total}, net = $option{net}\n\n";
        exit if $option{test};

        for my $col ( 0 .. @columns - 1 ) {
            $widget{pages}{$path}{ $columns[$col]{name} } = 0;
        }
        my $id = 0;
        for my $type ( sort keys %stats ) {
            $widget{pages}{$path}{list}->add($id);
            $widget{pages}{$path}{list}->itemCreate( $id, 0, -text => $type );
            for my $col ( 1 .. $#columns - 1 ) {
                $widget{pages}{$path}{list}->itemCreate( $id, $col, -text => comma($stats{$type}{ $columns[$col]{name} }) );
                $widget{pages}{$path}{ $columns[$col]{name} } += $stats{$type}{ $columns[$col]{name} } || 0;
            }
            $stats{$type}{net} = $stats{$type}{lines};
            for my $col ( 3 .. $#columns - 2 ) {
                $stats{$type}{net} -= $stats{$type}{ $columns[$col]{name} } || 0;
            }
            $widget{pages}{$path}{list}->itemCreate( $id, $#columns, -text => comma( $stats{$type}{net} ) );
            $widget{pages}{$path}{net} += $stats{$type}{net};
            $id++;
        }
        $widget{pages}{$path}{list}->add( $id++ );
        $widget{pages}{$path}{list}->add($id);
        $widget{pages}{$path}{list}->itemCreate( $id, 0, -text => '    Total ' );

        for my $col ( 1 .. $#columns ) {
            $widget{pages}{$path}{list}->itemCreate( $id, $col, -text => comma($widget{pages}{$path}{ $columns[$col]{name} }) );
        }
    }

    return;
}

sub new_stats_path {
    my $answer;
    my $new_dialog = $widget{mw}->DialogBox( -title => 'New Stat Directory', -buttons => [ 'OK', 'Cancel' ] );
    my $dir = $settings->{directories}{paths}[-1] || $CWD;

    $new_dialog->add(
        'LabEntry',
        -label        => 'New Directory :',
        -textvariable => \$dir,
        -width        => 50,
        -labelPack    => [ -side => 'left' ]
    )->pack( -side => 'top' );

    $answer = $new_dialog->Show;
    if ( $answer eq 'OK' ) {
        push @{ $settings->{directories}{paths} }, $dir;
        refresh_scs();
    }

    return;
}

sub refresh_scs {
    $widget{notebook}->packForget();

    $widget{notebook} = $widget{mw}->NoteBook( -font => 'Monospace 10 bold' )->pack( -side => 'right', -fill => 'both', -expand => 1 );
    scan_directories();

    return;
}

sub doxygenate {
    my $dir = shift;
    my ( $doxy, $config );

    $doxy   = $settings->{doxygen}{path}   ||= $option{'doxygen'};
    $config = $settings->{doxygen}{config} ||= 'SCS-Doxygen';
    $doxy =~ s{/}{\\}gxms;
    $dir  =~ s{/}{\\}gxms;
    print qq{"$doxy" -config "$config" "$dir"\n};

    return;
}

sub doxygen_path {
    my $new_dialog = $widget{mw}->DialogBox( -title => 'Set Path For Doxygen', -buttons => [ 'OK', 'Cancel' ] );
    my ( $dir, $answer );

    $dir = $settings->{doxygen}{path} ||= $option{'doxygen'};
    $new_dialog->add(
        'LabEntry',
        -label        => 'Doxygen Path :',
        -textvariable => \$dir,
        -width        => 50,
        -labelPack    => [ -side => 'left' ]
    )->pack( -side => 'top', -padx => '3', -pady => '3' );

    $answer = $new_dialog->Show;
    if ( $answer eq 'OK' ) {
        $settings->{doxygen}{path} = $dir;
    }

    return;
}

sub comma {

    my $number = shift || 0;

    my @digits = reverse split //xms, $number;
    my $text;

    for ( my $i = 0; $i < @digits; $i += 3 ) {
        $text = $text ? ",$text" : q{};
        $text = "$digits[$i]$text";

        if ( $i + 1 < @digits ) {
            $text = "$digits[$i+1]$text";

            if ( $i + 2 < @digits ) {
                $text = "$digits[$i+2]$text";

            }
        }
    }

    return $text;
}

sub exit_scs {
    my $geom = $widget{mw}->geometry;
    my ( $width, $height, $x, $y ) = $geom =~ /^ =? (\d+) x (\d+) [+-] (\d+) [+-] (\d+) $/xms;

    # check that we actually opened.
    if ( $height and $width ) {
        $settings->{window}{geometry} = $geom;
    }

    DumpFile( $option{config}, $settings );

    return exit 0;
}

sub menubar_etal {
    my $menu = [
        [
            'cascade',
            '~File',
            -menuitems => [
                [ 'command', '~New',          -accelerator => 'Ctrl-n', -command => \&new_stats_path ],
                [ 'command', '~Refresh',      -accelerator => 'Ctrl-s', -command => \&refresh_scs ],
                [ 'command', '~Doxygen Path', -accelerator => q{},       -command => \&doxygen_path ],
                q{},
                [ 'command', '~Exit', -accelerator => 'Alt-F4', -command => \&exit_scs ]
            ]
        ],
        [
            'cascade',
            '~Help',
            -menuitems => [
                [
                    'command',
                    'Version',
                    -command => sub {
                        $widget{mw}->messageBox( -title => "$name Version", -message => " This is $name Version $VERSION " );
                    }
                ],
                [
                    'command',
                    'About',
                    -command => sub {
                        $widget{mw}->messageBox(      -title   => "About $name",
                            -message => " This is the perl $name \n Author(s) : Ivan Wills "
                        );
                    }
                ]
            ]
        ]
    ];
    return $menu;
}

__DATA__

=head1 NAME

SourceCodeStats - Generates statistics of source code contained in directories.

=head1 VERSION

This documentation refers to SourceCodeStats version 0.1.

=head1 SYNOPSIS

   SourceCodeStats [option]

 OPTIONS:
  -a --add=dir  Add dir to the list of paths to display stats for.
  -s --simplify Show results baised on more generic terms than just the file
                suffix.
  -c --config=file|name
                Use the file as the YAML configoration file or the named
                config file in the default directory.
     --nogeom   Don't use the saved geomertry (occasionally this corrupted
                when SourceCodeStats crashes)

  -v --verbose  Show more detailed option
     --version  Prints the version information
     --help     Prints this help information
     --man      Prints the full documentation for SourceCodeStats

=head1 DESCRIPTION

Looks at all the files in the directories specified in the config and
calculates stats like the size, number of lines of comments, SLOC etc and
reports the results. This is to allow some overview of the size of a project
the proportion of the code that are comments etc.

=head1 SUBROUTINES/METHODS

=head3 open_window(I<  >)

Sets up the main window

=head3 scan_directories(I<  >)

Scans the directories and calculates the statistics for each

=head3 new_stats_path(I<  >)

Add a new path to monitor

=head3 refresh_scs(I<  >)

Refreshes all the scanned directories.

=head3 doxygenate(I< $dir >)

Run Doxygen on the directory $dir

=head3 doxygen_path(I<  >)

Run Doxygen on this directory

=head3 exit_scs(I<  >)

Synchronises the current file with the other directory

=head3 menubar_etal(I<  >)

Sets up the menu options

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 AUTHOR

Ivan Wills - (ivan.wills@gmail.com)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008 Ivan Wills (101 Miles St Bald Hills QLD Australia 4036).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
