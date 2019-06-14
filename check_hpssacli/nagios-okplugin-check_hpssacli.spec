%define debug_package %{nil}

Summary:	A Nagios plugin to check HP Array with hpssacli
Name:		nagios-okplugin-check_hpssacli
Version:	1.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_hpssacli
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_hpssacli/releases/nagios-okplugin-check_hpssacli-%{version}.tar.gz
Requires:	hpssacli
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Gardar Thorsteinsson <gardar@ok.is>


%description
Checks HP Array with hpssacli

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_hpssacli.cfg
perl -pi -e "s|/usr/lib64|%{_libdir}|g" sudoers.d/*

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_hpssacli.py %{buildroot}%{_libdir}/nagios/plugins/check_hpssacli.py
install -D -p -m 0755 nrpe.d/check_hpssacli.cfg %{buildroot}/etc/nrpe.d/check_hpssacli.cfg
install -D -p -m 0440 sudoers.d/check_hpssacli %{buildroot}/etc/sudoers.d/check_hpssacli

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_hpssacli.cfg
/etc/sudoers.d/check_hpssacli

%changelog
* Fri Jun 14 2019 Gardar Thorsteinsson <gardar@ok.is> 1.1
- Initial packaging
