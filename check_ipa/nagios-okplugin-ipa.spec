%define debug_package %{nil}
%define plugin ipa

Summary:	A Nagios plugin to check IPA server status
Name:		nagios-okplugin-%{plugin}
Version:	0.0.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/misc/tree/master/nagios-plugins/check_%{plugin}
Source0:	https://github.com/opinkerfi/misc/tree/master/nagios-plugins/check_%{plugin}/releases/%{name}-%{version}.tar.gz
Requires:	python-ldap
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>
BuildArch:	noarch
Requires:	nrpe


%description
Checks IPA server status

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_ipa_replication %{buildroot}%{_libdir}/nagios/plugins/check_ipa_replication
mkdir -p %{buildroot}%{_sysconfdir}/nrpe.d
sed "s^/usr/lib64^%{_libdir}^g" nrpe.d/check_ipa.cfg >  %{buildroot}%{_sysconfdir}/nrpe.d/check_ipa.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README
%{_libdir}/nagios/plugins/*
%config(noreplace) %{_sysconfdir}/nrpe.d/check_ipa.cfg

%changelog
* Thu Apr 25 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.3-1
- Preliminary testing done, released
- Various errors in syntax fixed (tommi@tommi.org)
- Detection for no configured replicas (tommi@tommi.org)

* Thu Apr 25 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.2-1
- Tagged new release

* Wed Apr 25 2013 Tomas Edwardss <tommi@opensource.is> 0.0.1-1
- Initial Packaging
