Introduction
============
Check http multi was created to check multiple websites in one plugin. You can check the following:

* Latency per website
* Overall runtime of http requests (serial)
* Number of failed websites
* Percentage of failed websites


How
===

Check Percentage Failed
-----------------------
Here we check http://www.google.com and http://adagios.org

Failure rates of 
* 0%-30% are ok
* 30%-60% are warning
* everything above is critical

```
$ check_http_multi -u http://www.google.com -u http://adagios.org/ \
    --th metric=failed_percentage,warning=30..60,critical=60..inf 
Checked 2 uris, 0 failed | 'http://www.google.com'=0.24s;;;; 'http://adagios.org/'=0.47s;;;; 'failed'=0;;;; 'failed_percentage'=0.0%;30..60;60..inf;; 'runtime'=0.711745977402s;;;;
http://www.google.com fetched in 0.24 seconds
http://adagios.org/ fetched in 0.47 seconds
```



Author
======
Tomas Edwardsson <tommi@tommi.org>


License
=======
GPLv3 or later
