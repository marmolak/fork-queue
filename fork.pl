#!/usr/bin/env perl 

use strict;
use warnings;
use utf8;
use POSIX ":sys_wait_h";
use Thread::Semaphore;

my %children;

my $max_fork = 4;

my $s = Thread::Semaphore->new ($max_fork);
my $boss_lock = Thread::Semaphore->new (0);

sub sig_handler {
	local ($!, $?);
	while ( (my $pid = waitpid (-1, WNOHANG)) > 0 ) {
		next unless defined $children{$pid};
		next if ( $children{$pid} == 0 );

		delete $children{$pid};

		if ( !%children ) {
			$boss_lock->up ();
		} else {
			$s->up ();
		}
	}
}

sub main {

	local $SIG{CHLD} = \&sig_handler;

	my $tasks = 100;

	for ( ; $tasks > 0; --$tasks ) {

		$s->down ();

		my $pid = fork ();
		if ( $pid > 0 ) {

			$children{$pid} = 1;

		} elsif ( $pid == 0 ) {
			$children{$pid} = 0;

			sleep (int (rand (2) + 5));
			exit (0);
		} elsif ( $pid == -1 ) {
			die "fork failed!";
		}
	}

	$boss_lock->down ();
}

main ();