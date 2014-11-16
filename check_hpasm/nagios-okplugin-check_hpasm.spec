%define debug_package %{nil}

Summary:	A Nagios plugin to check HP Hardware Status 
Name:		nagios-okplugin-check_hpasm
Version:	4.1.4
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_hpasm
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_hpasm/releases/nagios-okplugin-check_hpasm-%{version}.tar.gz
Requires:	nagios-okconfig-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>
BuildArch:	noarch



%description
A Nagios plugin to check HP Hardware Status


%prep
%setup -q

%build
perl -pi -e "s|/usr/lib|%{_libdir}|g" sudoers.d/check_hpasm
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_hpasm.cfg

%install
rm -rf %{buildroot}
install -D -p -m 0755 check_hpasm %{buildroot}%{_libdir}/nagios/plugins/check_hpasm
install -D -p -m 0440 sudoers.d/check_hpasm %{buildroot}/etc/sudoers.d/check_hpasm
install -D -p -m 0644 nrpe.d/check_hpasm.cfg %{buildroot}/etc/nrpe.d/check_hpasm.cfg


%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
#%{_libdir}/nagios/plugins/*
%{_libdir}/nagios/plugins/check_hpasm
/etc/sudoers.d/check_hpasm
/etc/nrpe.d/check_hpasm.cfg

%changelog
* Fri Oct 03 2014 Tomas Edwardsson <tommi@tommi.org> 4.1.4-1
- hpasm invalid nrpe check command name (tommi@tommi.org)

* Thu May 15 2014 Tomas Edwardsson <tommi@tommi.org> 4.1.3-1
- new package built with tito

* Tue Jun 4 2013 Pall Sigurdsson <palli@opensource.is> 4.1.2-1
- Initial packaging
