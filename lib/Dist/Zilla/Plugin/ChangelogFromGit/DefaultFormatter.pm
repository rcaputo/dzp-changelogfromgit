package Dist::Zilla::Plugin::ChangelogFromGit::DefaultFormatter;
use Moose;

with 'Dist::Zilla::Plugin::ChangelogFromGit::Formatter';

use Text::Wrap qw(wrap fill $columns $huge);

sub format {
    my ($self, $releases) = @_;

	$Text::Wrap::huge    = 'wrap';
	$Text::Wrap::columns = $self->wrap_column;
	
	my $changelog = '';
	
	foreach my $release (@{ $releases }) {

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
	
	my $max_age = 365;
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