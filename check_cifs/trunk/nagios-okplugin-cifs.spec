%define debug_package %{nil}

Summary:	A Nagios plugin to check CIFS shares
Name:		nagios-okplugin-cifs
Version:	0.0.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-Brocade
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_cifs/releases/nagios-okplugin-cifs-%{version}.tar.gz
Requires:	perl-Nagios-Plugin
Requires:	samba-client, krb5-workstation
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>
BuildArch:	noarch


%description
Checks CIFS fileshares, support writing and benchmarking, kerberos and
NTML authentication

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_cifs

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
* Mon Nov 21 2010  Tomas Edwardsson <tommi@ok.is> 0.0.3-1
- Initial packaging
