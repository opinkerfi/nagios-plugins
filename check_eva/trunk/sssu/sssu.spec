%define debug_package %{nil}

Summary:	Storage System Scripting Utility
Name:		sssu
Version:	9.2.0
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://www.hp.com
Source0:	http://www.hp.com/.../sssu-%{version}.tar.gz
Requires:	compat-libstdc++-33
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Pall Sigurdsson <palli@opensource.is>


%description
SSSU for HP StorageWorks Command View EVA. Storage System Scripting Utility

%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 sssu_%{_target} %{buildroot}/usr/bin/sssu

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/sssu

%changelog
* Mon Mar  1 2010  Pall Sigurdsson <palli@opensource.is> 0.1-1
- Initial packaging
