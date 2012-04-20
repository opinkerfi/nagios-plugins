%define debug_package %{nil}

Summary:	A Nagios plugin to check VMWare 3.x or 4.x via WBEM
Name:		nagios-okplugin-check_vmware_wbem
Version:	1.0.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_vmware_wbem
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_hpacucli/releases/nagios-okplugin-check_vmware_wbem-%{version}.tar.gz
Requires:	pywbem
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>


%description
A Nagios plugin to check VMWare 3.x or 4.x via WBEM

%prep
%setup -q
#perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_hpacucli.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_vmware_wbem %{buildroot}%{_libdir}/nagios/plugins/check_vmware_wbem

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*
#/etc/nrpe.d/check_hpacucli.cfg

%changelog
* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 1.0.1-1
- new package built with tito

* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
