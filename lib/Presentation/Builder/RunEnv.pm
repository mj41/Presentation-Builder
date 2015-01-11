package Presentation::Builder::RunEnv;

use strict;
use warnings;

sub new {
	my ( $class, %pars ) = @_;
	my $self = {};
	$self->{reset_env_rs} = $pars{reset_env} || sub {};
	$self->{init_env_rs} = $pars{init_env} || sub {};
	bless $self, $class;
}

sub reset_env {
	my ( $self ) = @_;
	return $self->{reset_env_rs}->();
}

sub init_env {
	my ( $self ) = @_;
	return $self->{init_env_rs}->();
}

sub run_sub {
	my ( $self, $sub_ref, $params ) = @_;
	return $sub_ref->( $params );
}


1;
