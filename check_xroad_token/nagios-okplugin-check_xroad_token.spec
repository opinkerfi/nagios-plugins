%define debug_package %{nil}

Summary:	A Nagios plugin to check status of XROAD soft-token
Name:		nagios-okplugin-check_xroad_token
Version:	1.2
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/issues
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_xroad_token/releases/nagios-okplugin-check_xroad_token-%{version}.tar.gz
Requires:	nagios-nrpe
Requires:	xroad-signer
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Gardar Thorsteinsson <gardar@ok.is>


%description
A Nagios plugin to check status of XROAD soft-token


%prep
%setup -q
#perl -pi -e "s|/usr/lib64|%{_libdir}|g" nrpe.d/check_xroad_token.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_xroad_token.sh %{buildroot}%{_libdir}/nagios/plugins/check_xroad_token.sh
install -D -p -m 0755 nrpe.d/check_xroad_token.cfg %{buildroot}/etc/nrpe.d/check_xroad_token.cfg
install -D -p -m 0644 sudoers.d/check_xroad_token %{buildroot}/etc/sudoers.d/check_xroad_token

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_xroad_token.cfg
/etc/sudoers.d/check_xroad_token

%post
restorecon -v %{_libdir}/nagios/plugins/check_xroad_token.sh /etc/nrpe.d/check_xroad_token.cfg /etc/sudoers.d/check_xroad_token

%changelog
* Mon Sep 14 2020 Your Name <you@example.com> 1.2-1
- new package built with tito

* Fri Sep 11 2020  Gardar Thorsteinsson <gardart@gmail.com> 1.0.1-1
- Initial packaging
