%define debug_package %{nil}

Summary:	A Nagios plugins to check if a specific linux module exists
Name:		nagios-okplugin-check_linux_modules
Version:	0.0.12
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_smssend
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>


%description
A Nagios plugins to check if a specific linux module exists

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_module.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_linux_module.pl %{buildroot}%{_libdir}/nagios/plugins/check_linux_module.pl
install -D -p -m 0755 nrpe.d/check_module.cfg %{buildroot}/etc/nrpe.d/check_module.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc  LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_module.cfg

%changelog
* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.12-1
- new package built with tito

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.11-1
- license added (palli@opensource.is)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.10-1
- 

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.9-1
- new package built with tito

