%define debug_package %{nil}
%define plugin check_msa_hardware
%define packager Pall Sigurdsson <palli@opensource.is>

Summary:	A Nagios plugin to check status of an MSA (HP P2000) disk array
Name:		nagios-okplugin-%{plugin}
Version:	1.0.3
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
Checks status of a remote MSA disk array, also known as HP P2000 
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
* Thu Jan 30 2014 Pall Sigurdsson <palli@opensource.is> 1.0.3-1
- new package built with tito

* Thu Jan 30 2014 Pall Sigurdsson <palli@opensource.is> 1.0.2-1
- new package built with tito

* Thu Jan 30 2014 Unknown name 1.0.1-1
- new package built with tito

* Fri Jan 27 2014 Pall Sigurdsson 1.0.0-1
- Initial Packaging
