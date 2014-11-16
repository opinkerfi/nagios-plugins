%define debug_package %{nil}

Summary:	A Nagios plugin to check uptime of a remote host via NRPE
Name:		nagios-okplugin-check_uptime
Version:	1.0.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_uptime
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_uptime/releases/nagios-okplugin-check_uptime-%{version}.tar.gz
Requires:	nagios-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>



%description
A Nagios plugin to check uptime of a remote host via NRPE


%prep
%setup -q
perl -pi -e "s|/usr/lib/|%{_libdir}/|g" nrpe.d/check_uptime.cfg
perl -pi -e "s|/usr/lib64/|%{_libdir}/|g" nrpe.d/check_uptime.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_uptime.sh %{buildroot}%{_libdir}/nagios/plugins/check_uptime.sh
install -D -p -m 0755 nrpe.d/check_uptime.cfg %{buildroot}/etc/nrpe.d/check_uptime.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_uptime.cfg

%changelog
* Sun Apr 13 2014 Tomas Edwardsson <tommi@tommi.org> 1.0.3-1
- Update tag

* Mon Dec 30 2013 Tomas Edwardsson <tommi@tommi.org> 1.0.2-1
- Updated tag for build with newer tito

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 1.0.1-1
- new package built with tito

* Thu Nov 25 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
