package Presentation::Builder::SlideCollection::Reveal;

use strict;
use warnings;

use base 'Presentation::Builder::SlideCollection';

use File::Slurp;
use File::Spec;
use HTML::Entities;
use HTML::FromANSI ();
use Text::Markdown;
use File::ShareDir ();

sub init {
	my ( $self ) = @_;
	$self->SUPER::init();
	$self->mandatory_param( $_ ) foreach qw/
		revealjs_dir
		out_fpath
	/;
	$self->{templ_dir} //= File::ShareDir::module_dir( ref($self) );
}

sub replace_var {
	my ( $self, $vars, $var_name ) = @_;

	return $vars->{$var_name} if exists $vars->{$var_name};
	warn "Variable '$var_name' isn't defined.\n";
	return '';
}

sub get_processed_templ_content {
	my ( $self, $fpath, $vars ) = @_;

	my $content = read_file( $fpath );
	$content =~ s{\@\@([a-zA-Z_\-0-9]+)\@\@}{&replace_var($self,$vars,$1)}ges;
	return $content;
}

sub out_fpath {
	my $self = shift;
	return $self->{out_fpath};
}

sub open_out_file {
	my ( $self ) = @_;
	open( $self->{out_fh}, '>:utf8', $self->{out_fpath} )
		|| die "Can't open '$self->{out_fpath}' for write: $!\n";
	return 1;
}

sub out {
	my ( $self, $html ) = @_;
	print {$self->{out_fh}} $html;
}

sub close_out_file {
	my ( $self ) = @_;
	close( $self->{out_fh} )
		|| die "Closing '$self->{out_fpath}' error: $!\n";
	return 1;
}

sub templ_fpath {
	my ( $self, $templ_rel_path ) = @_;
	return File::Spec->catfile( $self->{templ_dir}, $templ_rel_path );
}

sub process_templ {
	my ( $self, $templ_rel_path, $vars ) = @_;

	my $out = $self->get_processed_templ_content(
		$self->templ_fpath( $templ_rel_path ),
		$vars
	);
	return $self->out( $out );
}

sub main_vars {
	my ( $self ) = @_;

	return {
		title => $self->{title},
		subtitle => $self->{subtitle} || '',
		author => $self->{author},
		author_url => $self->{author_url} || '',
		date => $self->{date},
		description => $self->{description} || '',
	};
}

sub first_slides_vars {
	my ( $self, $vars ) = @_;

	my $first_slide_suffix_html = $self->{first_slide_suffix_html};
	unless ( $first_slide_suffix_html ) {
		$first_slide_suffix_html = $vars->{author_url}
			? qq|<small>by <a href="$vars->{author_url}">$vars->{author}</a></small>|
			:  qq|<small>by $vars->{author}</small>|
	}

	return {
		%$vars,
		first_slide_suffix_html => $first_slide_suffix_html,
	};
}

sub all_slides_begin {
	my ( $self ) = @_;
	$self->open_out_file();
	my $vars = $self->main_vars();
	$self->process_templ( 'all_slides_begin.templ', $vars );

	$self->process_templ(
		'first_slide.templ',
		$self->first_slides_vars( $vars )
	);
}

sub all_slides_end {
	my ( $self ) = @_;
	$self->process_templ( 'all_slides_end.templ', $self->main_vars() );
	$self->close_out_file();
}

sub slide_vars {
	my ( $self, $meta_data, $data_source_type ) = @_;
	return {
		slide_name => $meta_data->{slide_name},
	};
}

sub slide_begin {
	my $self = shift;
	$self->log_slide_begin( @_ );
	$self->process_templ( 'slide_begin.templ', $self->slide_vars( @_ ) );
}

sub slide_header {
	my $self = shift;
	$self->log_slide_header( @_ );
	$self->process_templ( 'slide_header.templ', $self->slide_vars( @_ ) );
}

sub slide_end {
	my $self = shift;
	$self->log_slide_end( @_ );
	$self->process_templ( 'slide_end.templ', $self->slide_vars( @_ ) );
}

sub esc {
	my ( $self, $text ) = @_;

	my $html = encode_entities( $text );
	return $html;

    my $h = HTML::FromANSI->new(
        #fill_cols => 1,
    );
    $h->add_text( $html );
    return $h->html;
}

sub add_slide_raw {
	my ( $self, $raw_out ) = @_;
	$self->log_add_slide_raw( $raw_out );
	$self->out( $raw_out );
	return $raw_out;
}

sub get_fragmet_html {
	my ( $self ) = @_;
	return ( $self->{ctx}{fragment_id} > 0 ) ? ' class="fragment"' : '';
}

sub add_slide_text {
	my $self = shift;
	$self->log_add_slide_text( @_ );
	my ( $meta_data, $data_source_type, $text ) = @_;

	my $fragment_html = $self->get_fragmet_html();
	$self->out( "<p$fragment_html>" );
	if ( $data_source_type eq 'markdown' ) {
		my $m = Text::Markdown->new;
		my $html = $m->markdown($text);
		$self->out( $html );
	} else {
		$self->out( $text );
	}
	$self->out( '</p>' );

	$self->fragment_added();
	return $text;
}

sub add_slide_cmd {
	my ( $self, $ci ) = @_;
	$self->log_add_slide_cmd( $ci );

	if ( $ci->{no} ) {
		return 1;
	}

	my $fragment_html = $self->get_fragmet_html();
	$self->out('<pre' . $fragment_html . '><code class="no-highlight" data-trim contenteditable>'."\n");
	$self->out(
		$self->esc("> ") . $self->esc($ci->{cmd}) . "\n"
	) if not $ci->{no_cmd};

	if ( (not $ci->{no_out}) && $ci->{out} ) {
		my $html_out = $self->esc( $ci->{out} );
		$self->out($html_out);
	}
	$self->out('</code></pre>'."\n");

	$self->fragment_added() if (not $ci->{no_out}) || (not $ci->{no_cmd});
	return 1;
}

1;
