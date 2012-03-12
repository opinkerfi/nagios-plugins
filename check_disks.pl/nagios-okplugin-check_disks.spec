%define debug_package %{nil}

Summary:	A Nagios plugin to check disks via NRPE
Name:		nagios-okplugin-check_disks
Version:	AUTOVERSION
Release:	2%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_disks
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_eva/releases/nagios-okplugin-check_disks-%{version}.tar.gz
Requires:	nagios-plugins-nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>
BuildArch:	noarch



%description
A Nagios plugin to check disks via NRPE


%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_disks.pl

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_disks.pl %{buildroot}%{_libdir}/nagios/plugins/check_disks.pl

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
#%{_libdir}/nagios/plugins/*
%{_libdir}/nagios/plugins/check_disks.pl

%changelog
* Sun Oct 16 2011  Tomas Edwardsson <tommi@opensource.is> 0.1-2
- Fixed dependencies and build arch

* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
