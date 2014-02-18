## Summary
Nethook is a daemon that runs scripts when network interfaces change state. I wrote nethook before I was aware of [ifup-local and ifdown-local](http://blog.dastrup.com/?p=52). You can probably use them instead.

## Usage
When a network interface goes down, the following locations are checked for scripts. If they exist and are executable, they are run.

  * /etc/nethook/ifup.d/`*`
  * /etc/nethook/ifup-$DEVICE

Similarly, when a network interface goes up, the following locations are checked for scripts to run.

  * /etc/nethook/ifdown.d/`*`
  * /etc/nethook/ifdown-$DEVICE

Prior to running the scripts, nethook parses /etc/sysconfig/network-scripts/ifcfg-$DEVICE if it exists and makes the variables set in it available in the scripts' environment.

## Requirements

Nethook was tested on Red Hat Enterprise Linux 5, aka RHEL5, but it should work on any similar distributions which

  * Place network interface configuration in /etc/sysconfig/network-scripts/ifcfg-`*`
  * When NICs change state, signal processes that called netreport

Nethook requires the following Perl modules, which are available in the EPEL repository.

  * perl-App-Daemon
  * perl-IO-Interface
  * perl-Log-Log4perl
  * perl-YAML

## Installation

    $ git clone git://github.com/sciurus/nethook.git
    $ mv nethook/nethook /usr/sbin/nethook
    $ mv init/sysv /etc/init.d/nethook
    $ chkconfig nethook on
    $ service nethook start

As of version 0.13, App::Daemon's status command returns LSB-compliant exit codes. If you're using this version, the third step could be replaced by `ln -s /usr/sbin/nethook /etc/init.d/nethook`.
