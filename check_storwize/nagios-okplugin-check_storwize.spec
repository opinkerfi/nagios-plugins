%define debug_package %{nil}
%define plugin check_storwize
%define packager Pall Sigurdsson <palli@opensource.is>

Summary:	A Nagios plugin to check status of a storwize disk array
Name:		nagios-okplugin-%{plugin}
Version:	1.0.0
Release:	1%{?dist}
License:	GPLv3+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/tree/master/%{plugin}
Source0:	https://github.com/opinkerfi/nagios-plugins/tree/master/%{plugin}/releases/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	%{packager}
BuildArch:	noarch
Requires:	pynag


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
* Fri Dec 6 2013 Pall Sigurdsson 1.0.0-1
- Initial Packaging
