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

Critical Security
-----------------

Critical on all security type updates
```
$ check_package_updates --no-longoutput --th "metric=security,critical=1..inf"
Critical - Total: 67, Security: 15, Bug fix: 48, Enhancement: 0, Normal: 4. Critical on security | 'total'=67;;;; 'security'=15;;1..inf;; 'bug fix'=48;;;; 'normal'=4;;;;
```

Total Updates
-------------

Critical on all security type updates and warning on many total updates
```
$ python check_package_updates --no-longoutput --th "metric=security,critical=1..inf" --th "metric=total,warning=40..inf"
Critical - Total: 67, Security: 15, Bug fix: 48, Enhancement: 0, Normal: 4. Critical on security. Warning on total | 'total'=67;40..inf;;; 'security'=15;;1..inf;; 'bug fix'=48;;;; 'normal'=4;;;;
```

Long Output
-----------
With long output (default) you also get the list of packages

```
$ python check_package_updates --th "metric=security,critical=1..inf" --th "metric=total,warning=40..inf"
Critical - Total: 32, Security: 1, Bug fix: 31, Enhancement: 0, Normal: 0. Critical on security | 'total'=32;40..inf;;; 'security'=1;;1..inf;; 'bug fix'=31;;;;
Security
  python-bugzilla-0.9.0-1.fc18.noarch
Bug fix
  ibus-typing-booster-1.2.1-1.fc18.noarch
  nodejs-abbrev-1.0.4-6.fc18.noarch
  nodejs-archy-0.0.2-8.fc18.noarch
  nodejs-async-0.2.9-2.fc18.noarch
  nodejs-block-stream-0.0.6-7.fc18.noarch
  nodejs-chmodr-0.1.0-4.fc18.noarch
  nodejs-chownr-0.0.1-9.fc18.noarch
  nodejs-combined-stream-0.0.4-3.fc18.noarch
  nodejs-delayed-stream-0.0.5-5.fc18.noarch
  nodejs-fstream-0.1.22-3.fc18.noarch
  nodejs-ini-1.1.0-3.fc18.noarch
  nodejs-lru-cache-2.3.0-3.fc18.noarch
  nodejs-mime-1.2.9-3.fc18.noarch
  nodejs-minimatch-0.2.12-2.fc18.noarch
  nodejs-mkdirp-0.3.5-3.fc18.noarch
  nodejs-mute-stream-0.0.3-6.fc18.noarch
  nodejs-node-uuid-1.4.0-4.fc18.noarch
  nodejs-nopt-2.1.1-3.fc18.noarch
  nodejs-once-1.1.1-5.fc18.noarch
  nodejs-opener-1.3.0-7.fc18.noarch
  nodejs-osenv-0.0.3-5.fc18.noarch
  nodejs-promzard-0.2.0-6.fc18.noarch
  nodejs-proto-list-1.2.2-5.fc18.noarch
  nodejs-read-1.0.4-8.fc18.noarch
  nodejs-retry-0.6.0-5.fc18.noarch
  nodejs-sigmund-1.0.0-5.fc18.noarch
  nodejs-tar-0.1.17-3.fc18.noarch
  nodejs-uid-number-0.0.3-7.fc18.noarch
  nodejs-which-1.0.5-8.fc18.noarch
  python-virtinst-0.600.4-2.fc18.noarch
  vgabios-0.6c-9.fc18.noarch
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
wget https://raw.github.com/opinkerfi/nagios-plugins/master/check_package_updates/check_package_updates
```

Room for improvement
====================

The plugin executes pkcon instead of using the API directly. I actually gave
the API a whirl via "from gi.repository import PackageKitGlib as packagekit"
but the documentation was very lacking so I ended up with pkcon.

License
=======
GPLv3 or newer, see LICENSE-GPL3 in the root of the project
