%define debug_package %{nil}

Summary:	A Nagios plugin to check Cisco Ironport 
Name:		nagios-okplugin-check_ironport
Version:	1.1.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_ironport/releases/%{name}-%{version}.tar.gz
Requires:	nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>
BuildArch:	noarch
Requires:	nrpe


%description
Checks the health status of a Cisco Ironport

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_ironport.py %{buildroot}%{_libdir}/nagios/plugins/check_ironport.py

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README
%{_libdir}/nagios/plugins/*
#%config(noreplace) %{_sysconfdir}/nrpe.d/check_bond.cfg

%changelog
* Tue Jul 31 2012 Pall Sigurdsson <palli@opensource.is> 1.1.3-1
- new package built with tito


* Tue Jul 31 2012  Pall Sigurdsson 1.0.0-1
- Initial packaging
