%define debug_package %{nil}
%define plugin check_ifoperstate

Summary:	A Nagios plugin to check interface operator status
Name:		nagios-okplugin-%{plugin}
Version:	0.0.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/misc/tree/master/nagios-plugins/check_%{plugin}
Source0:	https://github.com/opinkerfi/misc/tree/master/nagios-plugins/check_%{plugin}/releases/%{name}-%{version}.tar.gz
Requires:	nagios-okconfig-nrpe >= 0.0.4
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@tommi.org>
BuildArch:	noarch


%description
Checks the operator status of network interfaces

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
* Wed Jun 05 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.3-1
- Rename ifoperstate (tommi@tommi.org)

* Wed Jun 05 2013 Tomas Edwardsson <tommi@tommi.org> 0.0.2-1
- new package built with tito

