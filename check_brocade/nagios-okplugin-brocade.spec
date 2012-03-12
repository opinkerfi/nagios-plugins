%define debug_package %{nil}

Summary:	A Nagios plugin to check Brocade devices
Name:		nagios-okplugin-brocade
Version:	0.0.4
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-Brocade
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_brocade/releases/nagios-okplugin-brocade-%{version}.tar.gz
Requires:	perl-Nagios-Plugin
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>


%description
Checks Brocade devices

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_brocade_env

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_brocade_env %{buildroot}%{_libdir}/nagios/plugins/check_brocade_env

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*

%changelog
* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.4-1
- new package built with tito

* Mon Nov 21 2010  Tomas Edwardsson <tommi@ok.is> 0.0.3-1
- Initial packaging
