package Dist::Zilla::Plugin::ChangelogFromGit::Formatter;
use Moose::Role;

has wrap_column => (
	is      => 'ro',
	isa     => 'Int',
	default => 74,
);

requires 'format';

no Moose;
1;