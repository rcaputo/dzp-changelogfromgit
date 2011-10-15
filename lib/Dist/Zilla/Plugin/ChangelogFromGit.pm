package Dist::Zilla::Plugin::ChangelogFromGit;

# ABSTRACT: Build a Changes file from a project's git log.

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::FileGatherer';

use DateTime;
use DateTime::Infinite;
use Software::Release;
use Software::Release::Change;
use Git::Repository::Log::Iterator;
use POSIX qw(strftime);

has formatter_class => (
    is => 'ro',
    isa => 'Str',
    default => 'DefaultFormatter'
);

has max_age => (
	is      => 'ro',
	isa     => 'Int',
	default => 365,
);

has tag_regexp => (
	is      => 'ro',
	isa     => 'Str',
	default => '^v\\d+_\\d+$',
);

has file_name => (
	is      => 'ro',
	isa     => 'Str',
	default => 'CHANGES',
);

has wrap_column => (
	is      => 'ro',
	isa     => 'Int',
	default => 74,
);

has debug => (
	is      => 'ro',
	isa     => 'Int',
	default => 0,
);

sub gather_files {
	my ($self, $arg) = @_;

	# Find all release tags back to the earliest changelog date.

	my $earliest_date = DateTime->now->subtract(days => $self->max_age);

	chomp(my @tags = `git tag`);

    my @releases = ();
	{
		my $tag_pattern = $self->tag_regexp();

		my $i = @tags;
		while ($i--) {
			unless ($tags[$i] =~ /$tag_pattern/o) {
				splice @tags, $i, 1;
				next;
			}

			my $commit = `git show $tags[$i] --pretty='tformat:(((((%ct)))))' | grep '(((((' | head -1`;
			die $commit unless $commit =~ /\(\(\(\(\((\d+?)\)\)\)\)\)/;

            push(@releases, Software::Release->new(
                date    => DateTime->from_epoch(epoch => $1),
                version => $tags[$i]
            ));
		}

		@tags = sort { $a->{'time'} cmp $b->{'time'} } @tags;
	}

	# Add a virtual release for the most recent change in the
	# repository.  This lets us include changes after the last
	# releases, up to "HEAD".

	{
		chomp( my $head_version = `git rev-list HEAD | tail -1` );
		chomp( my $head_time    = `git show --format=%ct -n1 HEAD | head -1` );

		if ($head_version ne $releases[-1]->version()) {
			push @releases, (
				Software::Release->new(
					date    => DateTime->now(),
					version => 'HEAD',
				)
			);
		}
	}

    @releases = sort { DateTime->compare($a->date, $b->date) } @releases;

	{
		my $i = scalar(@releases);
		while ($i--) {
			my $this_release = $releases[$i];
			last if DateTime->compare($this_release->date, $earliest_date) == -1;

			my $prev_version = (
				$i
				? ($releases[$i-1]->version() . '..')
				: ''
			);

			my $release_range = $prev_version . $this_release->version();

			warn ">>> $release_range\n" if $self->debug();

            my $iter = Git::Repository::Log::Iterator->new($release_range);
            while (my $log = $iter->next) {

				warn "    ", $log->commit(), " ", $log->committer_localtime, "\n" if $self->debug();

	            $this_release->add_to_changes(
		            Software::Release::Change->new(
			            author_email    => $log->author_email,
			            author_name     => $log->author_name,
			            change_id       => $log->commit,
			            committer_email => $log->committer_email,
			            committer_name  => $log->committer_name,
			            date            => DateTime->from_epoch(epoch => $log->committer_localtime),
			            description     => $log->message
		            )
	            );
            };
		}
	}

    my $formclass = $self->formatter_class;
    if($formclass !~ /^\+/) {
        $formclass = "Dist::Zilla::Plugin::ChangelogFromGit::$formclass";
    }

    Class::MOP::load_class($formclass);

    my $formatter = $formclass->new(
		max_age => $self->max_age(),
		wrap_column => $self->wrap_column(),
	);

    my $changelog = $formatter->format(\@releases);

    my $file = Dist::Zilla::File::InMemory->new({
      content => $changelog,
      name    => $self->file_name(),
    });

    $self->add_file($file);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=head1 NAME

Dist::Zilla::Plugin::ChangelogFromGit - build CHANGES from git commits and tags

=head1 SYNOPSIS

In your dist.ini:

	[ChangelogFromGit]
	max_age     = 365
	tag_regexp  = ^v\d+_\d+$
	file_name   = CHANGES
	wrap_column = 74

The example values are the defaults.

=head1 DESCRIPTION

This Dist::Zilla plugin writes a CHANGES file that contains formatted
commit information from recent git logs.

This plugin has the following configuration variables:

=over 2

=item * max_age

It may be impractical to include the full change log in a mature
project's distribution.  "max_age" limits the changes to the most
recent ones within a number of days.  The default is about one year.

Include two years of changes:

	max_age = 730

=item * tag_regexp

This plugin breaks the changelog into sections delineated by releases,
which are defined by release tags.  "tag_regexp" may be used to focus
only on those tags that follow a particular release tagging format.
Some of the author's repositories contain multiple projects, each with
their own specific release tag formats, so that changelogs can focus
on particular projects' tags.  For instance, POE::Test::Loops' release
tags may be specified as:

	tag_regexp = ^ptl-

NOTE: Since the "usual" way of using git tags is to tag a release, that
means this module can't find the "next" tag! If you supply a capturing
regex that specifies where the version will be, it will be used to generate
the "next" tag. If the regexp fails to match the tag will default to the
version provided by Dist::Zilla.

	tag_regexp = ^ptl-(.+)$

=item * file_name

Everyone has a preference for their change logs.  If you prefer
lowercase in your change log file names, you migt specify:

	file_name = Changes

=item * wrap_column

Changes from different contributors tend to vary in format.  This
plugin uses Text::Wrap to normalize the width of commit messages.  The
"wrap_column" parameter may be used to alter the reformatted line
width.  If 74 is to short, one might specify:

	wrap_column = 78

=item * formatter_class

The name of the formatter class to use.  Dist::Zilla::Plugin::ChangelogFromGit
will be prepended to the class name unless it begins with a +.  This allows
you to specific a formatter of your own creation. (See below.)

=back

=head1 Rolling Your Own Formatter

This module ships with a default formatter object.  If you are interested in
making your own you can write a module that consumes the
L<Dist::Zilla::ChangelogFromGit::Formatter> role.  This role may be changed
in the future!

=head1 Subversion and CVS

This plugin is almost entirely a copy-and-paste port of a command-line
tool I wrote a while ago.  I also have tools to generate change logs
from CVS and Subversion commits.  If anyone is interested, plugins for
these other version control systems should be about an hour's work
apiece.

=head1 AUTHORS

Rocco Caputo <rcaputo@cpan.org> - Initial release, and ongoing
management and maintenance.

Cory G. Watson <gphat@cpan.org> - Created the formatting classes.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010-2011 by Rocco Caputo.

This is free software; you may redistribute it and/or modify it under
the same terms as the Perl 5 programming language itself.

=cut
