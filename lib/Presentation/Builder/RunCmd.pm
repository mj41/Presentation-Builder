package Presentation::Builder::RunCmd;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/cmdo cd/;

use open qw/:std :utf8/;


sub cmdo {
	my ( $cmd, %args ) = @_;
	return undef unless $cmd;

	my $out;
	if ( $args{no_run} ) {
		$out = $args{out} || '';
	} else {
		$out = `$cmd 2>&1`;
	}
	chomp( $out ) if $out;
	return {
		sub => 'cmdo',
		out => $out,
		cmd => $cmd,
		%args,
	};
}

sub cd {
	my ( $where, %args ) = @_;
	chdir( $where );

	my $cmd_to_log = ( $args{where_to_print} ) ? "cd $args{where_to_print}" : "cd $where";
	return {
		sub => 'cd',
		out => '',
		cmd => $cmd_to_log,
		no_out => 0,
		%args,
	};
}


1;