%define debug_package %{nil}

Summary:	Nagios plugins to check the status of MS-SQL Servers
Name:		nagios-okplugin-mssql
Version:	0.0.3
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://opensource.is/trac/wiki/nagios-MSSQL
Source0:	http://opensource.ok.is/trac/browser/nagios-plugins/check_mssql/releases/nagios-okplugin-mssql-%{version}.tar.gz
Requires:	perl-Nagios-Plugin
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@opensource.is>


%description
MS-SQL checks for health and size of MSSQL servers

%prep
%setup -q
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_mssql_dbsize
perl -pi -e "s|/usr/lib|%{_libdir}|g" check_mssql_health

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_mssql_dbsize %{buildroot}%{_libdir}/nagios/plugins/check_mssql_dbsize
install -D -p -m 0755 check_mssql_health %{buildroot}%{_libdir}/nagios/plugins/check_mssql_health

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*

%changelog
* Sun Nov 21 2010  Tomas Edwardsson <tommi@opensource.is> 0.0.3-1
- Initial packaging
