%define debug_package %{nil}

Summary:	A Nagios plugin to check network bond devices
Name:		nagios-okplugin-bond
Version:	0.0.1
Release:	2%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.ok.is/trac/wiki/Nagios-OKPlugin-Bond
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_bond/releases/%{name}-%{version}.tar.gz
Requires:	nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>
BuildArch:	noarch
Requires:	nrpe


%description
Checks the network bond device on a Linux machine

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_bond %{buildroot}%{_libdir}/nagios/plugins/check_bond
mkdir -p %{buildroot}%{_sysconfdir}/nrpe.d
sed "s^/usr/lib64^%{_libdir}^g" nrpe.d/check_bond.cfg >  %{buildroot}%{_sysconfdir}/nrpe.d/check_bond.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README
%{_libdir}/nagios/plugins/*
%config(noreplace) %{_sysconfdir}/nrpe.d/check_bond.cfg

%changelog
* Sun Oct 16 2011  Tomas Edwardsson <tommi@opensource.is> 0.1-2
- Added configuration into package

* Mon Mar  1 2010  Tomas Edwardsson <tommi@ok.is> 0.1-1
- Initial packaging
