%define debug_package %{nil}
%define plugin check_package_updates

Summary:	A Nagios plugin to check operating system updates
Name:		nagios-okplugin-%{plugin}
Version:	0.0.7
Release:	1%{?dist}
License:	GPLv3+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/tree/master/%{plugin}
Source0:	https://github.com/opinkerfi/nagios-plugins/tree/master/%{plugin}/releases/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@opensource.is>
BuildArch:	noarch
Requires:	nrpe
Requires:	pynag
Requires:	PackageKit


%description
Checks updates via PackageKit and can notify on various different situations

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 %{plugin} %{buildroot}%{_libdir}/nagios/plugins/%{plugin}
mkdir -p %{buildroot}%{_sysconfdir}/nrpe.d
sed "s^/usr/lib64^%{_libdir}^g" nrpe.d/%{plugin}.cfg >  %{buildroot}%{_sysconfdir}/nrpe.d/%{plugin}.cfg
# Temporary fix for selinux
chcon system_u:object_r:nagios_unconfined_plugin_exec_t:s0 %{plugin} %{buildroot}%{_libdir}/nagios/plugins/%{plugin}

%clean
rm -rf %{buildroot}

%post
/sbin/service nrpe status &> /dev/null && /sbin/service nrpe reload || :

%files
%defattr(-,root,root,-)
%doc README.md
%{_libdir}/nagios/plugins/*
%config(noreplace) %{_sysconfdir}/nrpe.d/%{plugin}.cfg

%changelog
* Fri Sep 13 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.7-1
- check_package_updates - minor refactor (palli@opensource.is)
- check_package_updates - fix inconsistent tab/space (palli@opensource.is)
- Removed obsoletes and thresholds (tommi@tommi.org)
- Removed Draft, should be working pretty good (tommi@tommi.org)
- Added --legacy to default since that is the default format (tommi@tommi.org)
- Added nrpe reload since moving from check_yum needs it (tommi@tommi.org)
- Added obsolete for okplugin check_updates (tommi@tommi.org)

* Tue Jul 16 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.6-1
- Fix failure on a fully patched system (tommi@tommi.org)

* Tue Jul 16 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.5-1
- Known types always have a metric, even if 0 (tommi@tommi.org)

* Tue Jul 16 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.4-1
- new package built with tito

* Tue Jul 16 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.3-1
- Plugin should conflict with check_yum (tommi@tommi.org)
- No obsolete (tommi@tommi.org)
- Obsolete nagios-okplugin-check_yum (tommi@tommi.org)

* Tue Jul 16 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.2-1
- new package built with tito

* Wed Jul 16 2013 Tomas Edwardsson <tommi@opensource.is> 0.0.1-1
- Initial Packaging
