%define debug_package %{nil}

Summary:	A Nagios plugin to get network statistics over NRPE
Name:		nagios-okplugin-get_network_stat
Version:	1.0.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/okc-get_network_stat
Source0:	https://github.com/opinkerfi/nagios-plugins/okc-get_network_stat/%{name}-%{version}.tar.gz
Requires:	nagios-plugins-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@tommi.org>
BuildArch:	noarch



%description
A Nagios plugin to get network statistics over NRPE


%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 okc-get_network_stat %{buildroot}%{_libdir}/nagios/plugins/okc-get_network_stat

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
#%{_libdir}/nagios/plugins/*
%{_libdir}/nagios/plugins/okc-get_network_stat

%changelog
* Wed Apr 02 2014 Tomas Edwardsson <tommi@tommi.org> 1.0.1-1
- new package built with tito

* Wed Apr  2 2014 Tomas Edwardsson <tommi@tommi.org> 1.0.0-1
- Initial release
