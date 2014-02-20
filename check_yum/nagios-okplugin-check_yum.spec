%define debug_package %{nil}

Summary:	A Nagios plugin to check yum updates via NRPE
Name:		nagios-okplugin-check_yum
Version:	1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_yum
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_yum/releases/nagios-okplugin-check_yum-%{version}.tar.gz
Requires:	nagios-okconfig-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@opensource.is>
BuildArch:	noarch



%description
A Nagios plugin to check for updates using yum via NRPE


%prep
%setup -q

%build
perl -pi -e "s|/usr/lib|%{_libdir}|g" sudoers.d/check_yum
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_yum.cfg

%install
rm -rf %{buildroot}
install -D -p -m 0755 check_yum %{buildroot}%{_libdir}/nagios/plugins/check_yum
install -D -p -m 0440 sudoers.d/check_yum %{buildroot}/etc/sudoers.d/check_yum
install -D -p -m 0644 nrpe.d/check_yum.cfg %{buildroot}/etc/nrpe.d/check_yum.cfg


%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
#%{_libdir}/nagios/plugins/*
%{_libdir}/nagios/plugins/check_yum
/etc/sudoers.d/check_yum
/etc/nrpe.d/check_yum.cfg

%changelog
* Thu Feb 20 2014 Pall Sigurdsson <palli@opensource.is> 1-1
- Merge branch 'master' of github.com:opinkerfi/nagios-plugins
  (palli@opensource.is)

* Mon May 27 2013 Tomas Edwardsson <tommi@tommi.org> 0.8.2-1
- Fixed nrpe with invalid libdir (tommi@tommi.org)

* Mon May 27 2013 Tomas Edwardsson <tommi@tommi.org> 0.8.1-1
- Added missing nrpe config (tommi@tommi.org)
- Initial rpm packaging (tommi@tommi.org)
- fix for changed output in list-security query (pall.valmundsson@gmail.com)
- Merge branch 'master' of github.com:opinkerfi/misc (palli@opensource.is)
- Added perfdata and longoutput with ERRATA IDs (tommi@tommi.org)
- Added perfdata and longoutput with ERRATA IDs (tommi@tommi.org)
- Updated to new upstream release (tommi@tommi.org)

* Tue Apr 16 2013 Tomas Edwardsson <tommi@opensource.is> 0.8.0-2
- Initial packaging
