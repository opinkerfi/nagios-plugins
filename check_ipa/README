check_ipa_replication
=====================
You need some configuration for this plugin to have access to replication
information.

Allow anonymous read to replication information
-----------------------------------------------
You will need to do this for every IPA server, masters and replicas

```
ldapmodify -x -D "cn=directory manager" -W -f grant_anonymous_replication_view.ldif -h ipa-host.example.com
```

Configure the directory manager credentials
-------------------------------------------
NOT RECOMENDED, you can use -D and -w with the directory manager credentials
and the plugin will work as expected.


