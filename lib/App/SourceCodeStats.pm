package App::SourceCodeStats;

# Created on: 2013-11-06 19:52:35
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use Moose;
use namespace::autoclean;
use version;
use Carp;
use Scalar::Util;
use List::Util;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use File::CodeSearch::Files;

our $VERSION = version->new('0.0.1');

has path => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    required => 1,
);
has file_checker => (
    is      => 'rw',
    isa     => 'File::CodeSearch::Files',
    builder => '_file_checker',
);

sub stats {
    my ($self) = @_;

    my @files = $self->get_files;
    my %stats;
    my @all_types = grep {$_ ne 'ignore' && $_ ne 'scripting' && $_ ne 'programing'} keys %{ $self->file_checker->type_suffixes };

    for my $file (@files) {
        my @types;
        for my $type (@all_types) {
            push @types, $type if $self->file_checker->types_match($file, $type);
        }
        @types = ('Unknown') if !@types;
        $stats{$file} = [ map {$self->file_stats($file, $_)} @types ];
    }

    return %stats;
}

sub file_stats {
    my ($self, $file, $type) = @_;

    my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat($file);
    my %stats = ( type => $type, bytes => $size );

    return \%stats if -B $file;

    open my $fh, '<', $file or die "Cannot open the file $file: $!";

    LINE:
    while ( my $line = <$fh> ) {
        $stats{lines}++;
        if ( $line =~ /^(\s+)$/ ) {
            $stats{blank}++;
            next LINE;
        }
        if ( $line =~ /^ \s* \W{1,2} \s* ( \W{1,2} \s* )? $/xms ) {
            $stats{simple}++;
        }

        if ( $type =~ m{^(perl|pl|pm|perl|t|cgi)$} ) {
            $stats{comment}++ if $line =~ /^\s*#/;
            if ( $line =~ /^=/ ) {
                $stats{comment}++;
                while ( my $comment = <$fh> ) {
                    $stats{lines}++;
                    $stats{comment}++;
                    last if $comment =~ /^=cut/;
                }
            }
        }
        elsif ( $type =~ m{^(pod)$} ) {
            # pod files are comments if they are not simple or blank
            $stats{comment}++ if $line !~ /^ \s* \W{1,2} \s* ( \W{1,2} \s* )? $/xms;
        }
        elsif ( $type =~ m{^(php)$} ) {
            $stats{comment}++ if $line =~ m{^\s*(#|//)};
            if ( $line =~ m{^\s*/\*} ) {
                $stats{comment}++;
                unless ( $line =~ m{\*/} ) {
                    while ( my $comment = <$fh> ) {
                        $stats{lines}++;
                        $stats{comment}++;
                        last if $comment =~ m{\*/};
                    }
                }
            }
        }
        elsif ( $type =~ m{^(c|cpp|h|hpp|js)$} ) {
            if ( $line =~ m{^\s*/\*} ) {
                $stats{comment}++;
                unless ( $line =~ m{\*/} ) {
                    while ( my $comment = <$fh> ) {
                        $stats{lines}++;
                        $stats{comment}++;
                        last if $comment =~ m{\*/};
                    }
                }
            }
            elsif ( $line =~ m{\s*//} ) {
                $stats{comment}++;
            }
        }
    }
    close $fh;
    return \%stats;
}

sub get_files {
    my ($self) = @_;
    my @search = $self->path->children;
    my @files;

    for my $child (@search) {
        next if $self->file_checker->types_match($child, 'ignore');

        if ( -d $child ) {
            push @search, $child->children;
        }
        else {
            push @files, $child;
        }
    }

    return @files;
}

sub _file_checker {
    my ($self) = @_;
    return File::CodeSearch::Files->new;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::SourceCodeStats - <One-line description of module's purpose>

=head1 VERSION

This documentation refers to App::SourceCodeStats version 0.0.1


=head1 SYNOPSIS

   use App::SourceCodeStats;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.


=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 C<stats ()>

Calculates the code statistics

=head2 C<file_stats ($file, $type)>

Get the statistics about an individual file

=head2 C<get_files ()>

Find all files that statistics should be calculated for.

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
<Author name(s)>  (<contact address>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013 Ivan Wills (14 Mullion Close, Hornsby Heights, NSW Australia 2077).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
