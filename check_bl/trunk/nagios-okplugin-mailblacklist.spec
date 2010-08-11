%define debug_package %{nil}

Summary:	A Nagios plugin to check SMTP blacklists
Name:		nagios-okplugin-mailblacklist
Version:	0.0.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-MailBlacklist
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_bl/releases/%{name}-%{version}.tar.gz
Requires:	nagios-plugins
Requires:	nagios-plugins-perl
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>


%description
Checks DNS Blacklists for existance of hosts

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_bl

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_bl %{buildroot}%{_libdir}/nagios/plugins/check_bl

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README COPYING
%{_libdir}/nagios/plugins/*

%changelog
* Mon Mar  1 2010  Tomas Edwardsson <tommi@ok.is> 0.1-1
- Initial packaging
