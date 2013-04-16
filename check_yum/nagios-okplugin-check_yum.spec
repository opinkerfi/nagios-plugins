%define debug_package %{nil}

Summary:	A Nagios plugin to check yum updates via NRPE
Name:		nagios-okplugin-check_yum
Version:	0.8.0
Release:	2%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_yum
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_yum/releases/nagios-okplugin-check_yum-%{version}.tar.gz
Requires:	nagios-okconfig-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@opensource.is>
BuildArch:	noarch



%description
A Nagios plugin to check for updates using yum via NRPE


%prep
%setup -q

%build
perl -pi -e "s|/usr/lib|%{_libdir}|g" sudoers.d/check_yum

%install
rm -rf %{buildroot}
install -D -p -m 0755 check_yum %{buildroot}%{_libdir}/nagios/plugins/check_yum
install -D -p -m 0440 sudoers.d/check_yum %{buildroot}/etc/sudoers.d/check_yum


%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
#%{_libdir}/nagios/plugins/*
%{_libdir}/nagios/plugins/check_yum
/etc/sudoers.d/check_yum

%changelog
* Tue Apr 16 2013 Tomas Edwardsson <tommi@opensource.is> 0.8.0-2
- Initial packaging
