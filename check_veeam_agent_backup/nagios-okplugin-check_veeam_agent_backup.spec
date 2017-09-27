%define debug_package %{nil}

Summary:	A Nagios plugin to check if veeam linux agent is backing up
Name:		nagios-okplugin-check_veeam_agent_backup
Version:	1.0.0
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/System
URL:		https://github.com/opinkerfi/nagios-plugins/issues
Source0:	https://github.com/samueljon/nagios-plugins
Requires:	nagios-nrpe
Requires:	veeam
Requires:	veeamsnap
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager:	Samúel Jón Gunnarsson <samuel@ok.is>



%description
A Nagios plugin to check if veeam linux agent is doing successful backups


%prep
%setup -q

%build


%install
rm -rf %{buildroot}
install -D -p -m 0755 check_veeam_agent_backup.sh %{buildroot}%{_libdir}/nagios/plugins/check_veeam_agent_backup.sh

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc README LICENSE
%{_libdir}/nagios/plugins/*

%post
restorecon -v %{_libdir}/nagios/plugins/check_veeam_agent_backup.sh

%changelog
* Wed Sep 27 2017  Samúel Jón Gunnarsson <samuel@ok.is> 1.0.0-1
- Initial packaging
