%define debug_package %{nil}

Summary:	A Nagios plugin to compare time on remote host with localhost
Name:		nagios-okplugin-time
Version:	AUTOVERSION
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_time
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_time/releases/nagios-okplugin-check_time-%{version}.tar.gz
Requires:	nagios-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>



%description
A Nagios plugin to compare time on remote host with localhos


%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_time.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_time %{buildroot}%{_libdir}/nagios/plugins/check_time
install -D -p -m 0755 nrpe.d/check_time.cfg %{buildroot}/etc/nrpe.d/check_time.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_time.cfg

%changelog
* Thu Nov 25 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
