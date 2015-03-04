package Presentation::Builder::SlideCollection;

use strict;
use warnings;

sub new {
	my ( $class, %args ) = @_;

	my $self = \%args;
	$self->{names} = [];
	$self->{data_src} = [];
	$self->{name2pos} = {};
	$self->{ctx} = {};
	$self->{sleep_mult} = $args{sleep_mult} // 1;
	$self->{vl} //= 3;
	bless $self, $class;

	$self->init();
	return $self;
}

sub mandatory_param {
	my ( $self, $name ) = @_;
	die "Parameter '$name' is mandatory.\n" unless $self->{$name};
}

sub init {
	my ( $self ) = @_;
	$self->mandatory_param( $_ ) foreach qw/title author date/;
}

sub add_slide {
	my ( $self, $name, $data_src1, $data_src2 ) = @_;

	$name = sprintf( 'Slide %02d', $#{$self->{data_src}} + 1) unless $name;
	die "Slide name '$name' already added as slide number $self->{name2pos}{$name}.\n"
		if exists $self->{name2pos}{$name};

	# Subroutine to run throug RunEnv/RunCmd.
	if ( ref $data_src1 eq 'CODE' ) {
		die "Method add_slide parameter error: second parameter is useless if cmd_sub provided."
			if defined $data_src2;
		push @{$self->{data_src}}, [ 'cmd_sub', $data_src1 ];

	# Text in any of supported formats to process.
	} else {
		my $data_source_type = $data_src1;
		my $supported = $self->supported_data_source_types();
		die "Data source type '$data_source_type' is not supported." unless $supported->{$data_source_type};
		push @{$self->{data_src}}, [ $data_source_type, $data_src2 ];
	}

	push @{$self->{names}}, $name;
	$self->{name2pos}{$name} = $#{$self->{data_src}};
	return 1;
}

sub char_line {
	my ( $self, $text, $char ) = @_;
	$char //= '-';
	return $char . " "  . $text . ' ' . ($char x (120-length($text)) ) . "\n";
}

sub all_slides_begin {
	my ( $self ) = @_;
	print $self->char_line( $self->{title} . ' by ' . $self->{author} . ' : ' . $self->{date} . ' (begin)', '*' );
}

sub all_slides_end {
	my ( $self ) = @_;
	print $self->char_line( $self->{name} . ' (end)', '*' );
}

sub log_slide_begin {
	my ( $self, $meta_data, $data_source_type ) = @_;
	return 1 unless $self->{vl} >= 4;
	print $self->char_line( $meta_data->{slide_name}, '=' );
}

sub slide_begin {
	my ( $self, $meta_data, $data_source_type ) = @_;
	$self->log_slide_begin( $meta_data, $data_source_type );
	return 1;
}

sub log_slide_end {
	my ( $self, $meta_data, $data_source_type ) = @_;
	return 1 unless $self->{vl} >= 4;
	print "\n\n";
}

sub slide_end {
	my ( $self, $meta_data, $data_source_type ) = @_;
	$self->log_slide_end( $meta_data, $data_source_type );
	return 1;
}

sub log_add_slide_raw {
	my ( $self, $raw_out ) = @_;
	return 1 unless $self->{vl} >= 4;
	print $raw_out;
}

sub add_slide_raw {
	my ( $self, $raw_out ) = @_;
	$self->log_add_slide_raw( $raw_out );
	return $raw_out;
}

sub fragment_reset {
	my ( $self ) = @_;
	$self->{ctx}{fragment_id} = 0;
	return 0;
}

sub fragment_added {
	my ( $self ) = @_;
	return $self->{ctx}{fragment_id}++;
}

sub log_add_slide_text {
	my ( $self, $meta_data, $data_source_type, $text ) = @_;
	return 1 unless $self->{vl} >= 4;
	print $text;
}

sub add_slide_text {
	my ( $self, $meta_data, $data_source_type, $text ) = @_;
	$self->log_add_slide_text( $meta_data, $data_source_type, $text );
	$self->fragment_added();
	return $text;
}

sub log_add_slide_cmd {
	my ( $self, $ci ) = @_;

	return 1 unless $self->{vl} >= 4;

	my $d_prefix = '|d| ';

	if ( $ci->{no} || $ci->{no_cmd} ) {
		print $d_prefix."> $ci->{cmd}\n";
	} else {
		print "> $ci->{cmd}\n";
	}

	if ( $ci->{no} || $ci->{no_out} ) {
		my $tmp_out = $ci->{out};
		$tmp_out =~ s{\n}{\n$d_prefix}mg;
		print $d_prefix."$tmp_out\n";
	} else {
		print "$ci->{out}\n";
	}
}

sub add_slide_cmd {
	my ( $self, $ci ) = @_;
	$self->log_add_slide_cmd( $ci );
	$self->fragment_added() if (not $ci->{no}) && ((not $ci->{no_out}) || (not $ci->{no_cmd}));
	return 1;
}

sub supported_data_source_types {
	return {
		'cmd_sub' => 1,
		'text' => 1,
		'markdown' => 1,
	};
}

sub get_slide_meta {
	my ( $self ) = @_;

	my $prev_result = undef;
	my $prev_name = $self->{ctx}{prev_name};
	$prev_result = $self->{all_results}{$prev_name} if defined $prev_name;
	return {
		slide_name => $self->{ctx}{name},
		prev_result => $prev_result,
		all_results => $self->{all_results},
	};
}

sub process_slide_part_simple {
	my ( $self, $name, $meta_data, $data_source_type, $data_source, $env ) = @_;

	if ( $data_source_type eq 'cmd_sub' ) {
		$self->{all_results}{$name} = $env->run_sub( $data_source, $meta_data );
	} else {
		$self->{all_results}{$name} = $self->add_slide_text( $meta_data, $data_source_type, $data_source );
	}
}

sub process_slide_part {
	my ( $self, $data_source_type, $data_source ) = @_;
	my $ctx = $self->{ctx};
	return $self->process_slide_part_simple(
		$ctx->{name},            # $name
		$self->get_slide_meta(), # $meta_data
		$data_source_type,       # $data_source_type
		$data_source,            # $data_source
		$ctx->{env},             # $env
	);
}

sub process_sleep {
	my ( $self, $sleep_time ) = @_;
	sleep $sleep_time * $self->{sleep_mult};
}

sub run_all {
	my ( $self, $env ) = @_;

	$env->reset_env();
	$self->{ctx} = {};
	$self->{ctx}{env} = $env;

	$self->all_slides_begin();
	$env->init_env();

	my $names = $self->{names};
	foreach my $slide_pos ( 0..$#$names ) {
		my $name = $names->[$slide_pos] || 'slide ' . ($slide_pos + 1);

		$self->{ctx}{name} = $name;
		$self->{ctx}{slide_pos} = $slide_pos;
		$self->fragment_reset();

		my ( $data_source_type, $data_source ) = @{ $self->{data_src}[$slide_pos] };
		my $meta_data = $self->get_slide_meta();
		$self->slide_begin( $meta_data, $data_source_type );
		$self->process_slide_part_simple( $name, $meta_data, $data_source_type, $data_source, $env );
		$self->slide_end( $meta_data, $data_source_type );
		$self->{ctx}{prev_name} = $name;
	}

	$self->all_slides_end();

	$self->{ctx}{env} = undef;
	$self->{ctx} = {};
	return 1;
}

sub process_command {
	my ( $self, $ci ) = @_;
	$self->add_slide_cmd( $ci );
	return $ci->{out};
}

1;
