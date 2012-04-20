%define debug_package %{nil}

Summary:	A Nagios plugin to check Linux Devicemapper Multipathing
Name:		nagios-okplugin-check_multipath
Version:	0.0.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_multipath
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_multipath/releases/nagios-okplugin-check_multipath-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Richard Allen <ra@opensource.is>


%description
Checks Linux Devicemapper Multipath devices

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_multipath.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_multipath %{buildroot}%{_libdir}/nagios/plugins/check_multipath
install -D -p -m 0755 nrpe.d/check_multipath.cfg %{buildroot}/etc/nrpe.d/check_multipath.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_multipath.cfg

%changelog
* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.3-1
- 

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.2-1
- new package built with tito

* Wed Feb 22 2012  Richard Allen <ra@opensource.is> 0.1-1
- Initial packaging
