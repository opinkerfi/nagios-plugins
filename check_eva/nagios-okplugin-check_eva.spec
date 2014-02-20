%define debug_package %{nil}

Summary:	A Nagios plugin to check HP EVA Disk Systems
Name:		nagios-okplugin-check_eva
Version:	2
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_eva
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_eva/releases/nagios-okplugin-check_eva-%{version}.tar.gz
Requires:	sssu,nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>



%description
Checks HP EVA Disk Systems with the sssu binary


%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_eva.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_eva.py %{buildroot}%{_libdir}/nagios/plugins/check_eva.py
install -D -p -m 0755 nrpe.d/check_eva.cfg %{buildroot}/etc/nrpe.d/check_eva.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_eva.cfg

%changelog
* Thu Feb 20 2014 Pall Sigurdsson <palli@opensource.is> 2-1
- Merge pull request #10 from gitmopp/patch-2 (palli-github@minor.is)
- bug in for loop. Looped only once (mopp@gmx.net)
- Fixed output to be more compatible (mopp@gmx.net)
- check_eva new Make sure --timeout is an integer (palli@opensource.is)
- check_eva new command line option --timeout (palli@opensource.is)
- check_eva Fix undefined fix typos (palli@opensource.is)
- PEP8 cleanup (palli@opensource.is)
- merged (palli@opensource.is)
- check_eva - minor bugfixes (palli@opensource.is)
- check_eva.py more code cleanup with pycharm inspections (palli@opensource.is)
- check_eva.py - Make code more readable (palli@opensource.is)
- convert from tabs to spaces (palli@opensource.is)
- check_eva - fix mixed tab/spaces (palli@opensource.is)
- Update check_eva.py (sander.grendelman@gmail.com)

* Thu Aug 23 2012 Pall Sigurdsson <palli@opensource.is> 1.0.2-1
- changed sssu subcommands from being singlequoted to doublequoted for windows
  compatibility (palli@opensource.is)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 1.0.1-1
- new package built with tito

* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
