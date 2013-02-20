#!/usr/bin/env perl 

use strict;
use warnings;
use utf8;
use POSIX ":sys_wait_h";
use Thread::Semaphore;

my %children;

my $max_fork = 4;
my $tasks_done = 0;
my $start_count = 0;

my $s = Thread::Semaphore->new ($max_fork);
my $boss_lock = Thread::Semaphore->new (0);

sub sig_handler {
	local ($!, $?);
	while ( (my $pid = waitpid (-1, WNOHANG)) > 0 ) {
		next unless defined $children{$pid};
		next if ( $children{$pid} == 0 );

		++$tasks_done;
		delete $children{$pid};

		if ( (!%children) && ($tasks_done == $start_count) ) {
			$boss_lock->up ();
		} else {
			$s->up ();
		}
	}
}

sub main {

	local $SIG{CHLD} = \&sig_handler;

	my $tasks = 10;
	$start_count = $tasks;

	for ( ; $tasks > 0; --$tasks ) {

		$s->down ();

		my $pid = fork ();
		$children{$pid} = 1;

		if ( $pid > 0 ) {
			# do nothing.
		} elsif ( $pid == 0 ) {
			undef $children{$pid};

			sleep (int (rand (2) + 5));
			exit (0);
		} elsif ( $pid == -1 ) {
			die "fork failed!";
		}
	}

	$boss_lock->down ();

	foreach my $pid (keys %children) {
		next if (waitpid ($pid, 0) < 0);
		delete $children{$pid};
	}
}

main ();
