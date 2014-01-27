%define debug_package %{nil}

Summary:	A Nagios plugin to check CPU on Linux servers
Name:		nagios-okplugin-check_cpu
Version:	1.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/
Source0:	https://github.com/opinkerfi/nagios-plugins/archive/%{name}-%{version}-%{release}.tar.gz
Requires:	nagios-okplugin-common
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@tommi.org>
BuildArch:	noarch

%description
Check cpu states on line machines

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 okplugin_check_cpu %{buildroot}%{_libdir}/nagios/plugins/okplugin_check_cpu
install -D -p -m 0755 nrpe.d/okplugin_check_cpu.cfg %{buildroot}/etc/nrpe.d/okplugin_check_cpu.cfg


%clean
rm -rf %{buildroot}

%post
/sbin/service nrpe reload

%files
%defattr(-,root,root,-)
%{_libdir}/nagios/plugins/*
%{_sysconfdir}/nrpe.d/*



%changelog
* Mon Jan 20 2014 Tomas Edwardsson <tommi@tommi.org> 1.1-1
- new package built with tito

* Thu Aug 23 2012 Pall Sigurdsson <palli@opensource.is> 1.0-1
- Version number bumped
- Updates buildarch to noarch (tommi@tommi.org)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.3-1
- new package built with tito

* Thu Nov 25 2010  Pall Sigurdsson <palli@opensource.is> 0.1-2
- Nrpe config now ships with plugin by default
* Mon Mar  1 2010  Tomas Edwardsson <tommi@ok.is> 0.1-1
- Initial packaging

