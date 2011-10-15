package Dist::Zilla::Plugin::ChangelogFromGit::Formatter;

# Indent style:
#   http://www.emacswiki.org/emacs/SmartTabs
#   http://www.vim.org/scripts/script.php?script_id=231
#
# vim: noexpandtab

use Moose::Role;

# ABSTRACT: Formatting role

has max_age => (
	is      => 'ro',
	isa     => 'Int',
	default => 365,
);

has wrap_column => (
	is      => 'ro',
	isa     => 'Int',
	default => 74,
);

requires 'format';

no Moose;
1;

__END__

=head1 NAME

Dist::Zilla::Plugin::ChangelogFromGit::Formatter - Role for formatters

=head1 SYNOPSIS

In your implementation:

	package My::Formatter;
	use Moose;

	with 'Dist::Zilla::Plugin::ChangelogFromGit::Formatter';

	sub format {
		my ($self, $releases) = @_;

		my $changelog = '';

		foreach my $release (@{ $releases }) {

			# Don't output empty versions.
			next if $release->has_no_changes;

			# Append something to $changelog from $release

			foreach my $change (@{ $release->changes }) {
				# Append something to $changelog from $change
			}
		}

		# This string will be output as your Changelog.
		return $changelog;
	}

	__PACKAGE__->meta->make_immutable;
	no Moose;
	1;

Then in your dist.ini:

	[ChangelogFromGit]
	... other stuff
	formatter_class = +My::Formatter

Mind the +!  Note that if you name your formatter
Dist::Zilla::Plugin::ChangelogFromGit::Whatever then you can just put

	formatter_class = Formatter

=head1 DESCRIPTION

The role provides the accessors common to formatters and requires the
implementation of C<format>, which receives an arrayref of
L<Software::Release> objects in reverse chronological order.

=head1 AUTHOR

Cory Watson <gphat@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Infinity Interactive, Inc.

This is free software; you may redistribute it and/or modify it under
the same terms as the Perl 5 programming language itself.

=cut
