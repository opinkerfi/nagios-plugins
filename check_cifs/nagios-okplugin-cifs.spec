%define debug_package %{nil}

Summary:	A Nagios plugin to check CIFS shares
Name:		nagios-okplugin-cifs
Version:	1.1
Release:	2%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-Brocade
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_cifs/releases/nagios-okplugin-cifs-%{version}.tar.gz
Requires:	perl-Nagios-Plugin
Requires:	samba-client, krb5-workstation
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager: Gardar Thorsteinsson <gardar@ok.is>	
BuildArch:	noarch


%description
Checks CIFS fileshares, support writing and benchmarking, kerberos and
NTML authentication

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_cifs

%global __requires_exclude %{?__requires_exclude:%__requires_exclude}|}^perl\\(utils\\)

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_cifs %{buildroot}%{_libdir}/nagios/plugins/check_cifs

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*

%changelog
* Fri May 09 2018 Gardar Thorsteinsson <gardar@ok.is> 1.1-2
- Filter out perl-utils dep

* Thu Feb 20 2014 Pall Sigurdsson <palli@opensource.is> 1.1-1
- Merge github.com:opinkerfi/misc (palli@opensource.is)

* Thu Aug 23 2012 Pall Sigurdsson <palli@opensource.is> 1.0-1
- version number of scripts bumped (palli@opensource.is)
- Updates buildarch to noarch (tommi@tommi.org)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.4-1
- new package built with tito

* Mon Nov 21 2010  Tomas Edwardsson <tommi@ok.is> 0.0.3-1
- Initial packaging
