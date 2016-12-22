%define debug_package %{nil}

Summary:	A Nagios plugin to check if iptables are actually enforcing rules
Name:		nagios-okplugin-check_firewall_active
Version:	1.0.2
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/issues
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_firewall_active/releases/nagios-okplugin-check_firewall_active-%{version}.tar.gz
Requires:	nagios-nrpe
Requires:	iptables
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Richard Allen <ra@ok.is>



%description
A Nagios plugin to check if iptables are actually enforcing rules


%prep
%setup -q
#perl -pi -e "s|/usr/lib64|%{_libdir}|g" nrpe.d/check_firewall_active.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_firewall_active.sh %{buildroot}%{_libdir}/nagios/plugins/check_firewall_active.sh
install -D -p -m 0755 nrpe.d/check_firewall_active.cfg %{buildroot}/etc/nrpe.d/check_firewall_active.cfg
install -D -p -m 0644 sudoers.d/check_firewall_active %{buildroot}/etc/sudoers.d/check_firewall_active

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_firewall_active.cfg
/etc/sudoers.d/check_firewall_active

%post
restorecon -v %{_libdir}/nagios/plugins/check_firewall_active.sh /etc/nrpe.d/check_firewall_active.cfg /etc/sudoers.d/check_firewall_active

%changelog
* Thu Dec 21 2016  Gardar Thorsteinsson <gardart@gmail.com> 1.0.1-1
* Thu Dec 21 2016  Gardar Thorsteinsson <gardart@gmail.com> 1.0.0-3
* Thu Dec 20 2016  Richard Allen <ra@ok.is> 0.1-1
- Initial packaging
