%define debug_package %{nil}

Summary:	Various nagios plugins to check cpu,memory,interfaces via SNMP
Name:		nagios-okplugin-check_snmp
Version:	2
Release:	2%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_snmp
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_snmp/releases/nagios-okplugin-check_snmp-%{version}.tar.gz
Requires:	perl-Net-SNMP
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Gardar Thorsteinsson <gardar@ok.is>


%description
Various nagios plugins to check cpu,memory,interfaces via SNMP

%prep
%setup -q
#perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_hpacucli.cfg

%global __requires_exclude %{?__requires_exclude:%__requires_exclude}|}^perl\\(utils\\)

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_snmp_connectivity %{buildroot}%{_libdir}/nagios/plugins/check_snmp_connectivity
install -D -p -m 0755 check_snmp_cpfw.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_cpfw.pl
install -D -p -m 0755 check_snmp_env.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_env.pl
install -D -p -m 0755 check_snmp_interfaces %{buildroot}%{_libdir}/nagios/plugins/check_snmp_interfaces
install -D -p -m 0755 check_snmp_int.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_int.pl
install -D -p -m 0755 check_snmp_load.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_load.pl
install -D -p -m 0755 check_snmp_mem.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_mem.pl
install -D -p -m 0755 check_snmp_patchlevel.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_patchlevel.pl
install -D -p -m 0755 check_snmp_temperature.pl %{buildroot}%{_libdir}/nagios/plugins/check_snmp_temperature.pl


%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*

%changelog
* Fri May 09 2018 Gardar Thorsteinsson <gardar@ok.is> 2-2
- Filter out perl-utils dep

* Thu Feb 20 2014 Pall Sigurdsson <palli@opensource.is> 2-1
- make sure nagios does not run us in embedded perl (palli@opensource.is)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 1.0.1-1
- new package built with tito

* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
