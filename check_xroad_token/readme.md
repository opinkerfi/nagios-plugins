# Required steps to use this check

```shell
# On RHEL/Centos
sudo semanage permissive -a nrpe_t
sudo setsebool -P nagios_run_sudo 1
sudo yum install nagios-okplugin-check_xroad_token -y
sudo systemctl restart nrpe
```
