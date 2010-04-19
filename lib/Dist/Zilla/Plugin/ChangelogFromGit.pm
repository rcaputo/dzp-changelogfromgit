package Dist::Zilla::Plugin::ChangelogFromGit;

# ABSTRACT: Build a Changes file from a project's git log.

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::FileGatherer';

use Text::Wrap qw(wrap fill $columns $huge);
use POSIX qw(strftime);

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

sub gather_files {
	my ($self, $arg) = @_;

	my $earliest_date = strftime(
		"%FT %T +0000", gmtime(time() - $self->max_age() * 86400)
	);

	$Text::Wrap::huge    = "wrap";
	$Text::Wrap::columns = $self->wrap_column();

	chomp(my @tags = `git tag`);

	{
		my $tag_pattern = $self->tag_regexp();

		my $i = @tags;
		while ($i--) {
			unless ($tags[$i] =~ /$tag_pattern/o) {
				splice @tags, $i, 1;
				next;
			}

			my $commit =
				`git show $tags[$i] --pretty='tformat:(((((%ci)))))' | grep '(((((' | head -1`;
			die $commit unless $commit =~ /\(\(\(\(\((.+?)\)\)\)\)\)/;

			$tags[$i] = {
				'time' => $1,
				'tag'  => $tags[$i],
			};
		}
	}

	push @tags, {'time' => '9999-99-99 99:99:99 +0000', 'tag' => 'HEAD'};

	@tags = sort { $a->{'time'} cmp $b->{'time'} } @tags;

	my $changelog = "";

	{
		my $i = @tags;
		while ($i--) {
			last if $tags[$i]{time} lt $earliest_date;

			my @commit;

			open my $commit, "-|", "git log $tags[$i-1]{tag}..$tags[$i]{tag} ."
				or die $!;
			local $/ = "\n\n";
			while (<$commit>) {
				if (/^\S/) {
					s/^/  /mg;
					push @commit, $_;
					next;
				}

				# Trim off identical leading whitespace.
				my ($whitespace) = /^(\s*)/;
				if (length $whitespace) {
					s/^$whitespace//mg;
				}

				# Re-flow the paragraph if it isn't indented from the norm.
				# This should preserve indented quoted text, wiki-style.
				unless (/^\s/) {
					push @commit, fill("    ", "    ", $_), "\n\n";
				}
				else {
					push @commit, $_;
				}
			}

			# Don't display the tag if there's nothing under it.
			next unless @commit;

			my $tag_line = "$tags[$i]{time} $tags[$i]{tag}";
			$changelog .= (
				("=" x length($tag_line)) . "\n" .
				"$tag_line\n" .
				("=" x length($tag_line)) . "\n\n"
			);

			$changelog .= $_ foreach @commit;
		}
	}

	my $epilogue = "End of changes in the last " . $self->max_age() . " day";
	$epilogue .= "s" unless $self->max_age() == 1;

	$changelog .= (
		("=" x length($epilogue)) . "\n" .
		"$epilogue\n" .
		("=" x length($epilogue)) . "\n"
	);

	my $file = Dist::Zilla::File::InMemory->new({
		content => $changelog,
		name    => $self->file_name(),
	});

	$self->add_file($file);
	return;
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

=back

=head1 Subversion and CVS

This plugin is almost entirely a copy-and-paste port of a command-line
tool I wrote a while ago.  I also have tools to generate change logs
from CVS and Subversion commits.  If anyone is interested, plugins for
these other version control systems should be about an hour's work
apiece.

=head1 AUTHOR

Rocco Caputo <rcaputo@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Rocco Caputo.

This is free software; you may redistribute it and/or modify it under
the same terms as the Perl 5 programming language itself.

=cut
