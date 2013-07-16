About
=====

This Nagios plugin checks for available updates using PackageKit
http://packagekit.org/ on Linux systems

Draft
=====
The implementation isn't finished yet.

Why a new plugin?
=================

There are already plugins out there like check_yum and check_apt which do
check for updates but they are distribution specific. The main drivers are:

* Can run unprivileged, for instance the nrpe user
* No sudo/selinux problems
* Non distribution specific, works on debian, ubuntu, fedora, centos, rhel...

Usage
=====

Critical on all security type updates
-------------------------------------
```
$ check_pkgkit --no-longoutput --th "metric=security,critical=1..inf"
Critical - Total: 67, Security: 15, Bug fix: 48, Enhancement: 0, Normal: 4. Critical on security | 'total'=67;;;; 'security'=15;;1..inf;; 'bug fix'=48;;;; 'normal'=4;;;;
```

Critical on all security type updates and warning on many total updates
-----------------------------------------------------------------------
```
$ python check_pkgkit --no-longoutput --th "metric=security,critical=1..inf" --th "metric=total,warning=40..inf"
Critical - Total: 67, Security: 15, Bug fix: 48, Enhancement: 0, Normal: 4. Critical on security. Warning on total | 'total'=67;40..inf;;; 'security'=15;;1..inf;; 'bug fix'=48;;;; 'normal'=4;;;;
```



Caveats
=======
* PackageKit does draw in quite a few packages with it.
* Does not work on older distros, like centos/rhel 5.

Dependencies
============

* pynag-0.4.7+
* Known to work with PackageKit 0.7.6 or later

Install
=======

* Install pynag (available through your favorite package manager)
* Install PackageKit (packagekit in Debian)

```
wget https://raw.github.com/opinkerfi/nagios-plugins/master/check_pkgkit/check_pkgkit
```

Room for improvement
====================

The plugin executes pkcon instead of using the API directly. I actually gave
the API a whirl via "from gi.repository import PackageKitGlib as packagekit"
but the documentation was very lacking so I ended up with pkcon.

License
=======
GPLv3 or newer, see LICENSE-GPL3 in the root of the project
