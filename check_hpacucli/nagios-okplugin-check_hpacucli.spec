%define debug_package %{nil}

Summary:	A Nagios plugin to check HP Array with hpacucli
Name:		nagios-okplugin-check_hpacucli
Version:	2
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_hpacucli
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_hpacucli/releases/nagios-okplugin-check_hpacucli-%{version}.tar.gz
Requires:	hpacucli
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>


%description
Checks HP Array with hpacucli

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_hpacucli.cfg
perl -pi -e "s|/usr/lib64|%{_libdir}|g" sudoers.d/*

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_hpacucli.py %{buildroot}%{_libdir}/nagios/plugins/check_hpacucli.py
install -D -p -m 0755 nrpe.d/check_hpacucli.cfg %{buildroot}/etc/nrpe.d/check_hpacucli.cfg
install -D -p -m 0440 sudoers.d/check_hpacucli %{buildroot}/etc/sudoers.d/check_hpacucli

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_hpacucli.cfg
/etc/sudoers.d/check_hpacucli

%changelog
* Thu Feb 20 2014 Pall Sigurdsson <palli@opensource.is> 2-1
- check_hpacucli.py - fix typo in hpacucli command (palli@opensource.is)
- check_hpacucli.py: pep8 cleanup (palli@opensource.is)
- check_hpacucli - fix tab indentation (palli@opensource.is)
- check_hpacucli: ignore hpacucli output that starts with "Note:"
  (palli@opensource.is)
- sudoers.d added to install (you@example.com)
- dummy commit (you@example.com)
- dummy commit (you@example.com)
- Add sudoers support to check_hpacucli (palli@opensource.is)

* Thu Aug 23 2012 Pall Sigurdsson <palli@opensource.is> 1.2-2
- version number of scripts bumped (palli@opensource.is)

* Thu Aug 23 2012 Pall Sigurdsson <palli@opensource.is> 1.2-1
- check_command is now sudo'ed (palli@opensource.is)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.3-1
- new package built with tito

* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
