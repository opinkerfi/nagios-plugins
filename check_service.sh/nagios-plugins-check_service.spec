%define debug_package %{nil}

Summary:	A Nagios plugin to check services on Linux servers
Name:		nagios-plugins-check_service
Version:	0
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/jonschipp/nagios-plugins/blob/master/check_service.sh
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_service/releases/nagios-plugins-check_service-%{version}.tar.gz
Requires:	nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Gardar Thorsteinsson <gardar@ok.is>
BuildArch:	noarch

%description
Check status of system services for Linux, FreeBSD, OSX, and AIX.

%prep
%setup -q
perl -pi -e "s|/usr/lib/|%{_libdir}/|g" nrpe.d/check_service.cfg
perl -pi -e "s|/usr/lib64/|%{_libdir}/|g" nrpe.d/check_service.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_service.sh %{buildroot}%{_libdir}/nagios/plugins/check_service.sh
install -D -p -m 0755 nrpe.d/check_service.cfg %{buildroot}/etc/nrpe.d/check_service.cfg

%clean
rm -rf %{buildroot}

%post
/sbin/service nrpe reload

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_service.cfg


%changelog
* Tue Apr 21 2020  <gardar@ok.is> 0.1-1
- Initial packaging

