%define debug_package %{nil}

Summary:	A Nagios plugin to check HP Array with hpacucli
Name:		nagios-okplugin-check_hpacucli
Version:	0.0.2
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

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_hpacucli.py %{buildroot}%{_libdir}/nagios/plugins/check_hpacucli.py
install -D -p -m 0755 nrpe.d/check_hpacucli.cfg %{buildroot}/etc/nrpe.d/check_hpacucli.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_hpacucli.cfg

%changelog
* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
