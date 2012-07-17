%define debug_package %{nil}

Summary:	A Nagios plugin to check IBM Bladecenters 
Name:		nagios-okplugin-check_ibm_bladecenter
Version:	1.1.2
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-check_ibm_bladecenter
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_ibm_bladecenter/releases/%{name}-%{version}.tar.gz
Requires:	nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>
BuildArch:	noarch
Requires:	nrpe


%description
Checks the health status of an IBM Bladecenter via SNMP

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_ibm_bladecenter.py %{buildroot}%{_libdir}/nagios/plugins/check_ibm_bladecenter.py
#mkdir -p %{buildroot}%{_sysconfdir}/nrpe.d
#sed "s^/usr/lib64^%{_libdir}^g" nrpe.d/check_bond.cfg >  %{buildroot}%{_sysconfdir}/nrpe.d/check_bond.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README
%{_libdir}/nagios/plugins/check_ibm_bladecenter.py
#%config(noreplace) %{_sysconfdir}/nrpe.d/check_bond.cfg

%changelog
* Tue Jul 17 2012 Pall Sigurdsson <palli@opensource.is> 1.1.2-1
- rpm spec file added. version number bumped (palli@opensource.is)

* Tue Jul 17 2012 Pall Sigurdsson <palli@opensource.is> 1.1.1-1
- new package built with tito


* Tue Jul 17 2012  Pall Sigurdsson 1.0.0-1
- Initial packaging
