%define debug_package %{nil}

Summary:	A Nagios plugins to check if /var/spool/smssend/incoming has any new messages
Name:		nagios-okplugin-check_smssend
Version:	0.0.11
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/check_smssend
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>


%description
A Nagios plugins to check if /var/spool/smssend/incoming has any new messages

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" nrpe.d/check_smssend.cfg

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_smssend %{buildroot}%{_libdir}/nagios/plugins/check_smssend
install -D -p -m 0755 nrpe.d/check_smssend.cfg %{buildroot}/etc/nrpe.d/check_smssend.cfg

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc  LICENSE
%{_libdir}/nagios/plugins/*
/etc/nrpe.d/check_smssend.cfg

%changelog
* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.11-1
- license added (palli@opensource.is)

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.10-1
- 

* Mon Mar 12 2012 Pall Sigurdsson <palli@opensource.is> 0.0.9-1
- new package built with tito

