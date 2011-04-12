#! /usr/bin/env perl

# http://search.cpan.org/~mschilli/App-Daemon-0.11/Daemon.pm
# http://search.cpan.org/~lds/IO-Interface-1.05/Interface.pm

# would be nice to support debian variables as well
# http://www.debian.org/doc/manuals/debian-reference/ch05.en.html#_scripting_with_the_ifupdown_system

use strict;
use warnings;

use App::Daemon qw(daemonize);
use IO::Interface::Simple;
use YAML qw(DumpFile);
use Data::Dumper;

$App::Daemon::logfile = '/var/log/nethook.log';
$App::Daemon::pidfile = '/var/run/nethook.pid';
$App::Daemon::as_user = 'root';

$SIG{'IO'}   = 'wakeup';
$SIG{'TERM'} = 'shutdown';
$SIG{'INT'}  = 'shutdown';

my $state_dir    = '/var/lib/nethook';
my $state = "$state_dir/state.yml";
my $conf_dir = '/etc/nethook';

# ifup.d/ and ifdown.d/ for scripts that run for every interface
# ifup-$DEVICE and ifdown-$DEVICE for interface specific scripts

daemonize();

startup();

sub startup {
    print "Started\n";

    unless (-d $state_dir) {
        mkdir $state_dir;
    }

    unless (-d $conf_dir) {
        mkdir $conf_dir;
    }

    unless (-d "$conf_dir/ifup.d") {
        mkdir "$conf_dir/ifup.d";
    }

    unless (-d "$conf_dir/ifdown.d") {
        mkdir "$conf_dir/ifdown.d";
    }

    my %current_interfaces = status_by_interface();
    YAML::DumpFile( $state, %current_interfaces ) or die "Unable to save state\n";

    system('/sbin/netreport') == 0
      or die 'Unable to request notification of network interface changes';

    while (1) {
        print "Zzz\n";
        sleep(60);
    }

}

# SIGIO handler
sub wakeup {
    print "Yawn\n";
    my %previous_interfaces = YAML::LoadFile($state);
    my %current_interfaces = status_by_interface();
    YAML::DumpFile( $state, %current_interfaces ) or die "Unable to save state\n";

    my @gone_down = ();
    my @gone_up   = ();
    for my $i ( keys %previous_interfaces ) {
        my $was_running = $previous_interfaces{$i};
        my $is_running  = $current_interfaces{$i};
        if ( $was_running == $is_running ) {
            next;
        }
        else {
            if ($was_running) {
                push( @gone_down, $i );
            }
            else {
                push( @gone_up, $i );
            }
        }
    }

    for my $i (@gone_down) {
        print "$i went down\n";
	my $ifcfg = "/etc/sysconfig/network-scripts/ifcfg-$i";
	if ( -r $ifcfg ) {
            my @variables_set = set_environment($ifcfg);
            opendir my $dh, "$conf_dir/ifdown.d";
            my @scripts = ();
            while ( my $f = readdir $dh ) {
               next if $f =~ /^\./;
               push(@scripts, "$conf_dir/ifdown.d/$f");
            }
            closedir $dh;
            push(@scripts, "$conf_dir/ifdown-$i");
            for my $s ( @scripts ) {
                if ( -f $s and -x $s) {
                    my $return = system($s);
                    print "$s returned $return\n";
                }
            }
            unset_environment(@variables_set);
	}
    }
    for my $i (@gone_up) {
        print "$i went up\n";
    }

    # for each interface that went up
    #     read values of /etc/sysconfig/network-scripts/ifcfg-$DEVICE into ENV
    #     run any scripts in ifup.d
    #     run ifup-$DEVICE ifit exists
    # similar work for any interfaces that went down
}

# SIGKILL handler
sub shutdown {
    print "Bye!\n";
    system('/sbin/netreport -r');
    unlink($state);
    exit(0);
}

sub status_by_interface {
    my @interfaces = IO::Interface::Simple->interfaces;
    my %results;
    for my $i (@interfaces) {
        if ( $i->is_running ) {
            $results{$i} = 1;
        }
        else {
            $results{$i} = 0;
        }
    }
    return %results;
}

sub set_environment {
    my $source = shift;
    my @names = ();
    open my $fh, '<', $source or die "Unable to read interface configuration\n";
    while (my $line = <$fh>) {
        if ($line =~ /^#/) {
            next;
        }
        unless ($line =~ /=/) {
            next;
        }
        my ($name, $value) = split('=', $line);
        if ( exists $ENV{$name} ) {
           print "Not clobbering existing environment variable $name\n";
        }
        else {
            $ENV{$name} = $value;
            push(@names, $name);
        }
    }
    close $fh;
    return @names;
}

sub unset_environment {
    my @names = @_;
    for my $n ( @names ) {
	print "Deleting $n\n";
        delete $ENV{$n};
    }
}
