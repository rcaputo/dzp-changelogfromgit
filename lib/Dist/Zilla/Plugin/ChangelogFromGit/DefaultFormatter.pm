package Dist::Zilla::Plugin::ChangelogFromGit::DefaultFormatter;
use Moose;

# ABSTRACT: Default formatter

with 'Dist::Zilla::Plugin::ChangelogFromGit::Formatter';

use Text::Wrap qw(wrap fill $columns $huge);

sub format {
    my ($self, $releases) = @_;

	$Text::Wrap::huge    = 'wrap';
	$Text::Wrap::columns = $self->wrap_column;
	
	my $changelog = '';
	
	foreach my $release (reverse @{ $releases }) {

        # Don't output empty versions.
        next if $release->has_no_changes;

        my $tag_line = $release->date.' '.$release->version;
        $changelog .= (
            ("=" x length($tag_line)) . "\n" .
            "$tag_line\n" .
            ("=" x length($tag_line)) . "\n\n"
        );


	    foreach my $change (@{ $release->changes }) {
	        
	        $changelog .= fill("    ", "    ", 'commit '.$change->change_id)."\n";
	        $changelog .= fill("    ", "    ", 'Author: '.$change->author_name.' <'.$change->author_email.'>')."\n";
	        $changelog .= fill("    ", "    ", 'Date: '.$change->date)."\n\n";
	        unless ($change->description =~ /^\s/) {
                $changelog .= fill("    ", "    ", $change->description)."\n\n";
            }
	    }
	}
	
	my $max_age = $self->max_age;
    my $epilogue = "End of changes in the last " . $max_age . " day";
    $epilogue .= "s" unless $max_age == 1;
    
    $changelog .= (
      ("=" x length($epilogue)) . "\n" .
      "$epilogue\n" .
      ("=" x length($epilogue)) . "\n"
    );
	
	return $changelog;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=head1 NAME

Dist::Zilla::Plugin::ChangelogFromGit::DefaultFormatter - Default formatting for the changelog

=head1 SYNOPSIS

In your dist.ini:

	[ChangelogFromGit]
	max_age     = 365
	tag_regexp  = ^v\d+_\d+$
	file_name   = CHANGES
	wrap_column = 74

The example values are the defaults.  This class is the default formatter,
but may be explicitly set with:

    formatter_class = Default

=head1 DESCRIPTION

The class implements the default format output by
L<Dist::Zilla::PLugin::ChangelogFromGit>.

=head1 AUTHOR

Rocco Caputo <rcaputo@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Rocco Caputo.

This is free software; you may redistribute it and/or modify it under
the same terms as the Perl 5 programming language itself.

=cut
