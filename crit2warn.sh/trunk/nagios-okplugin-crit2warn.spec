%define debug_package %{nil}

Summary:	A Nagios plugin wrapper that changes critical to warnings
Name:		nagios-okplugin-crit2warn
Version:	0.0.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-Crit2warn
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/crit2warn/releases/%{name}-%{version}.tar.gz
Requires:	nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@opensource.is>


%description
Modifies critical return code of plugins to warning

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 crit2warn.sh %{buildroot}%{_libdir}/nagios/plugins/crit2warn.sh

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%{_libdir}/nagios/plugins/*

%changelog
* Mon Mar  1 2010  Tomas Edwardsson <tommi@opensource.is> 0.1-1
- Initial packaging
