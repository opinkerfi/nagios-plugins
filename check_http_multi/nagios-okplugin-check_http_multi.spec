%define debug_package %{nil}
%define plugin check_http_multi

Summary:	A Nagios plugin to check multiple websites
Name:		nagios-okplugin-%{plugin}
Version:	0.1.1
Release:	1%{?dist}
License:	GPLv3+
Group:		Applications/System
URL:		https://github.com/opinkerfi/misc/tree/master/nagios-plugins/check_%{plugin}
Source0:	https://github.com/opinkerfi/misc/tree/master/nagios-plugins/check_%{plugin}/releases/%{name}-%{version}.tar.gz
Requires:	nagios-okconfig-nrpe >= 0.0.4
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@tommi.org>
BuildArch:	noarch


%description
Checks multiple websites for latency and failures. You can specify how many
of them will fail to return warning or critical state.

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 %{plugin} %{buildroot}%{_libdir}/nagios/plugins/%{plugin}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README.md
%{_libdir}/nagios/plugins/*

%changelog
* Thu Jun 06 2013 Tomas Edwardsson <tommi@tommi.org> 0.1.1-1
- new package built with tito

