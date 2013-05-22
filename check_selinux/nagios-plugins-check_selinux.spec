%define debug_package %{nil}

Summary:	A Nagios plugin to check SELinux status on Linux servers
Name:		nagios-plugins-check_selinux
Version:	1.0
Release:	1%{?dist}
License:	GPLv3+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/tree/master/check_selinux
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_selinux/releases/nagios-plugins-check_selinux-%{version}.tar.gz
Requires:	nagios-plugins-nrpe libselinux-utils
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>
BuildArch:	noarch

%description
This plugin check the enforcing selinux status of a specified host, using NRPE
if the host is remote.

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
install -D -p -m 0755 check_selinux %{buildroot}%{_libdir}/nagios/plugins/check_selinux

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%{_libdir}/nagios/plugins/*


%changelog
* Wed May 22 2013 Tomas Edwardsson <tommi@opensource.is> 1.0-1
- Initial packaging
