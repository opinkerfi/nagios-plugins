%define debug_package %{nil}

Summary:	A Nagios plugin to check network bond devices
Name:		nagios-okplugin-bond
Version:	0.0.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-Bond
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_bl/releases/%{name}-%{version}.tar.gz
Requires:	nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>


%description
Checks the network bond device on a Linux machine

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_bond %{buildroot}%{_libdir}/nagios/plugins/check_bond

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README
%{_libdir}/nagios/plugins/*

%changelog
* Mon Mar  1 2010  Tomas Edwardsson <tommi@ok.is> 0.1-1
- Initial packaging
