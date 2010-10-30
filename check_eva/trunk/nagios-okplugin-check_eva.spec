%define debug_package %{nil}

Summary:	A Nagios plugin to check HP EVA Disk Systems
Name:		nagios-okplugin-check_eva
Version:	AUTOVERSION
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_eva
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_eva/releases/nagios-okplugin-check_eva-%{version}.tar.gz
Requires:	sssu,nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>



%description
Checks HP EVA Disk Systems with the sssu binary


%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_eva.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_eva.py %{buildroot}%{_libdir}/nagios/plugins/check_eva.py
install -D -p -m 0755 nrpe.d/check_eva.cfg %{buildroot}/etc/nrpe.d/check_eva.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_eva.cfg

%changelog
* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
