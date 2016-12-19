# Zenloadbalancer 3.10.1 for Debian Jessie

[ZEVENET Load Balancer](https://www.zevenet.com) Community Edition (**Zen Load
Balancer** CE next generation) is an Open Source Load Balancer Project that
provides a full set of tools to run and manage a complete load balancer
solution which includes: farm and server definition, networking, clustering,
monitoring, secure certificates management, logs, configuration backups, uplink
load balancing support, and much more.

This github repo is a fork of [zlb](https://github.com/zevenet/zlb)

* Removed all bundled binary components: pound, mini-httpd, pen, ucarp, and etc
 (they are required as dependencies of package)

* Removed ads from main page

* Debianization (Debian Jessie x86\_64)

## Build binary and source packages

    $ git clone https://github.com/vlet/zlb zenloadbalancer-3.10.1

    $ tar --exclude='*/debian*' -cf zenloadbalancer_3.10.1.orig.tar zenloadbalancer-3.10.1

    $ gzip zenloadbalancer_3.10.1.orig.tar

    $ cd zenloadbalancer-3.10.1

    $ export QUILT_PATCHES=debian/patches

    $ while quilt push; do quilt refresh; done

    $ dpkg-buildpackage

Package will be available in the top dir: `zenloadbalancer_3.10.1-2_all.deb`

## Installation

Before instaling zenloadbalancer you will need to build those perl packages
(not available in official debian jessie repos):

* libgd-3dbargrapher-perl
* libnet-ssh-expect-perl

But this is not a problem to build it yourself, for example:


    $ dh-make-perl make --build --cpan net-ssh-expect
    ...
    dpkg-deb: building package `libnet-ssh-expect-perl' in `../libnet-ssh-expect-perl_1.09-1_all.deb'.
    ...

    $ sudo dpkg -i libnet-ssh-expect-perl_1.09-1_all.deb

Also Debian Jessie doesn't include mini_httpd package, so, you need to backport
it from old repo yourself.

After installing all required modules and mini_httpd install zenloadbalancer package:

    $ sudo dpkg -i zenloadbalancer_3.10.1-2_all.deb

## Disclaimer

zenloadbalancer removes all configuration from `/etc/network/interfaces` and
start managing instarfaces by itself. So you are required to have a direct
concole access to server (via kvm or ilo) if something going wrong.

DON'T install it on production server or your workstation , test package on a
separate (virtual) instance.
