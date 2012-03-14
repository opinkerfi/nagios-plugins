%define debug_package %{nil}

%define plugin_name	check_drbd
%define version		0.0.3


Summary:	A Nagios plugin to check Linux Devicemapper Multipathing
Name:		nagios-okplugin-%{plugin_name}
Version:	%{version}
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/%{plugin_name}
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/%{plugin_name}/releases/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>


%description
%{summary}

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/%{plugin_name}.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_drbd %{buildroot}%{_libdir}/nagios/plugins/check_drbd
install -D -p -m 0755 nrpe.d/%{plugin_name}.cfg %{buildroot}/etc/nrpe.d/%{plugin_name}.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/%{plugin_name}.cfg

%changelog
* Wed Mar 14 2012 Pall Sigurdsson <palli@opensource.is> 0.0.3-1
- new package built with tito

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.2-1
- new package built with tito
