%define debug_package %{nil}

Summary:	A Nagios plugin to check CPU on Linux servers
Name:		nagios-plugins-check_cpu
Version:	0.1
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		http://www.matejunkie.com/cpu-check-plugin-for-nagios/
Source0:	http://www.monitoringexchange.org/attachment/download/Check-Plugins/Operating-Systems/check_cpu-sh/check_cpu.sh
Requires:	nagios-plugins
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Tomas Edwardsson <tommi@ok.is>

%description
This shell script checks cpu utilization (user,system,iowait,idle in %) 
through /proc/stat accepting seperate threshholds and returning the data in a 
format suitable for performance data processing

%prep
#%setup -q -n nagios-check_sip-%{version}
#cp %{SOURCE1} %
# lib64 fix
#perl -pi -e "s|/usr/lib|%{_libdir}|g" check_sip

%build

%install
rm -rf %{buildroot}
install -D -p -m 0755 %{SOURCE0} %{buildroot}%{_libdir}/nagios/plugins/check_cpu.sh

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
#%doc README COPYING CHANGES
%{_libdir}/nagios/plugins/check_cpu.sh

%changelog
* Mon Mar  1 2010  Tomas Edwardsson <tommi@ok.is> 0.1-1
- Initial packaging
