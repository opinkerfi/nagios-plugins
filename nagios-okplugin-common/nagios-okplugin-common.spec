%define debug_package %{nil}

Summary:	A common package for the okplugin suite
Name:		nagios-okplugin-common
Version:	1.2
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/
Source0:	https://github.com/opinkerfi/nagios-plugins/archive/%{name}-%{version}-%{release}.tar.gz
Requires:	nrpe
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>
BuildArch:	noarch

%description
Common utilities for okplugins

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
mkdir -m 0770 -p %{buildroot}%{_sharedstatedir}/nagios-okplugin

%clean
rm -rf %{buildroot}

%post

%files
%defattr(-,root,root,-)
%dir %attr(0770, nrpe, nrpe) %{_sharedstatedir}/nagios-okplugin

%changelog
* Mon Jan 20 2014 Tomas Edwardsson <tommi@tommi.org> 1.2-1
- 

* Mon Jan 20 2014 Tomas Edwardsson <tommi@tommi.org> 1.1-1
- new package built with tito

* Mon Jan 20 2014 Tomas Edwardsson <tommi@tommi.org> 1.0-1
- Initial build
