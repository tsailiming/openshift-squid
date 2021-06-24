# Test Squid in parent child configuration 

# Architecture

```
NS user1-dev: CURL_POD  ===\
                            >===>  SQUID (whitelisting)  ====>  SQUID-EXT  ====> INTERNET 
NS user2-dev: CURL_POD  ===/
```

curl google.com should be allowed from user1-dev namespace

curl google.com should be disallowed from user1-dev namespace


# Fetch the pod names

```
SQUID_POD=`kubectl get pod -l deployment=squid -n squid -o jsonpath={.items..metadata.name}`; echo $SQUID_POD
SQUID_POD_EXT=`kubectl get pod -l app=openshift-squid -n squid-ext -o jsonpath={.items..metadata.name}`; echo $SQUID_POD_EXT

CURL_POD1=`kubectl get pod -l deployment=curl -n user1-dev -o jsonpath={.items..metadata.name}`; echo $CURL_POD1
CURL_POD2=`kubectl get pod -l deployment=curl -n user2-dev -o jsonpath={.items..metadata.name}`; echo $CURL_POD2
```

# Config of  squid for whitelisting 

```
$ k exec $SQUID_POD -n squid -- cat /etc/squid/squid.conf
pid_filename /tmp/${service_name}.pid
cache_dir null /tmp
logfile_rotate 0

cache_log stdio:/dev/null
access_log stdio:/dev/stdout
cache_store_log stdio:/dev/stdout

cache_peer openshift-squid.squid-ext.svc.cluster.local parent 3128 0 no-query default
never_direct allow all

http_port 3128

auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid Basic Authentication
auth_param basic credentialsttl 24 hours
auth_param basic casesensitive off

acl http proto http
acl port_80 port 80
acl CONNECT method CONNECT

acl user1 proxy_auth user1
acl user1_whitelist dstdomain "/etc/squid/whitelists/user1-whitelist.txt"
http_access allow user1_whitelist user1 

acl user2 proxy_auth user2
acl user2_whitelist dstdomain "/etc/squid/whitelists/user2-whitelist.txt"
http_access allow user2_whitelist user2 
```

# Config of external squid 

```
$ k exec $SQUID_POD_EXT -n squid-ext -- cat /etc/squid/squid.conf
pid_filename /tmp/${service_name}.pid
cache_dir null /tmp
logfile_rotate 0

# Disable logging
cache_log stdio:/dev/null
access_log stdio:/dev/stdout
cache_store_log stdio:/dev/stdout

http_port 3128

acl http proto http
acl port_80 port 80
acl port_443 port 443
acl CONNECT method CONNECT

http_access allow all
http_access deny all
```

# Test the curl pod - allowed 

```
sbylo$ k exec $CURL_POD1 -n user1-dev -- curl -sI google.com 
HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/
....
```

# Test the curl pod - forbidden 

```
sbylo$ k exec $CURL_POD1 -n user1-dev -- curl -sI cnn.com 
HTTP/1.1 403 Forbidden
Server: squid/4.11
Mime-Version: 1.0
Date: Thu, 24 Jun 2021 02:58:39 GMT
...
```

# Check the Squid logs 

```
k logs $SQUID_POD_EXT -n squid-ext  -f

1624503507.214     11 10.128.2.3 TCP_MISS/301 504 HEAD http://google.com/ - HIER_DIRECT/172.217.194.101 text/html 
```

```
k logs $SQUID_POD -n squid  -f

2021/06/24 02:58:27 kid1| Starting new basicauthenticator helpers...
2021/06/24 02:58:27 kid1| helperOpenServers: Starting 1/5 'basic_ncsa_auth' processes
2021/06/24 02:58:27 kid1| WARNING: no_suid: setuid(0): (1) Operation not permitted
1624503507.214     21 10.131.0.17 TCP_MISS/301 643 HEAD http://google.com/ user1 FIRSTUP_PARENT/172.30.199.53 text/html
1624503519.394      0 10.131.0.17 TCP_DENIED/403 412 HEAD http://cnn.com/ - HIER_NONE/- text/html
1624503519.394 RELEASE -1 FFFFFFFF 02000000000000000B00000001000000  403 1624503519         0        -1 text/html;charset=utf-8 3582/3582 HEAD http://cnn.com/
```

# TESTING 

```
CURL_POD1=`kubectl get pod -l deployment=curl -n user1-dev -o jsonpath={.items..metadata.name}`; echo $CURL_POD1
CURL_POD2=`kubectl get pod -l deployment=curl -n user2-dev -o jsonpath={.items..metadata.name}`; echo $CURL_POD2

sbylo$ k exec $CURL_POD1 -n user1-dev -- curl -o /dev/null -s -w "%{http_code}\n" google.com
301
```

# Here is the squid log for the above google curl request 

```
2021/06/24 03:27:18 kid1| Starting new basicauthenticator helpers...
2021/06/24 03:27:18 kid1| helperOpenServers: Starting 1/5 'basic_ncsa_auth' processes
2021/06/24 03:27:18 kid1| WARNING: no_suid: setuid(0): (1) Operation not permitted
2021/06/24 03:27:18 kid1| temporary disabling (Forbidden) digest from openshift-squid.squid-ext.svc.cluster.local
1624505238.045 RELEASE -1 FFFFFFFF 02000000000000000900000001000000  403 1624505238        -1        -1 text/html 3938/-606 GET http://openshift-squid.squid-ext.svc.cluster.local:3128/squid-internal-periodic/store_digest
1624505238.053     19 10.131.0.17 TCP_MISS/301 862 GET http://google.com/ user1 FIRSTUP_PARENT/172.30.199.53 text/html
```

# Squid ext log for the above google curl request

```
1624505238.045      0 10.128.2.1 TCP_MISS/403 4377 GET http://openshift-squid-74664bdd8-ft7z8:3128/squid-internal-periodic/store_digest - HIER_NONE/- text/html
1624505238.045 RELEASE -1 FFFFFFFF 03000000000000000A00000001000000  403 1624505238         0        -1 text/html;charset=utf-8 3938/3938 GET http://openshift-squid-74664bdd8-ft7z8:3128/squid-internal-periodic/store_digest
1624505238.045      3 10.128.2.49 TCP_MISS/403 4543 GET http://openshift-squid.squid-ext.svc.cluster.local:3128/squid-internal-periodic/store_digest - HIER_DIRECT/172.30.199.53 text/html
1624505238.045 RELEASE -1 FFFFFFFF 02000000000000000A00000001000000  403 1624505238        -1        -1 text/html 3938/3938 GET http://openshift-squid.squid-ext.svc.cluster.local:3128/squid-internal-periodic/store_digest
1624505238.053     11 10.128.2.49 TCP_MISS/301 723 GET http://google.com/ - HIER_DIRECT/74.125.130.138 text/html
```

# Other tests

```
sbylo$ k exec $CURL_POD2 -n user2-dev -- curl -o /dev/null -s -w "%{http_code}\n" google.com
403
```

# Squid log (no squid ext log)

```
1624505250.202      0 10.131.0.13 TCP_DENIED/403 4002 GET http://google.com/ user2 HIER_NONE/- text/html
1624505250.202 RELEASE -1 FFFFFFFF 03000000000000000900000001000000  403 1624505250         0        -1 text/html;charset=utf-8 3590/3590 GET http://google.com/
```

```
sbylo$ k exec $CURL_POD1 -n user1-dev -- curl -o /dev/null -s -w "%{http_code}\n" cnn.com
403
```

# Squid log (no squid ext log)

```
1624505264.849      0 10.131.0.17 TCP_DENIED/403 3993 GET http://cnn.com/ - HIER_NONE/- text/html
1624505264.849 RELEASE -1 FFFFFFFF 04000000000000000900000001000000  403 1624505264         0        -1 text/html;charset=utf-8 3581/3581 GET http://cnn.com/
```

```
sbylo$ k exec $CURL_POD2 -n user2-dev -- curl -o /dev/null -s -w "%{http_code}\n" cnn.com
403
```

# Squid log (no squid ext log)

```
1624505273.302      0 10.131.0.13 TCP_DENIED/403 3993 GET http://cnn.com/ - HIER_NONE/- text/html
1624505273.302 RELEASE -1 FFFFFFFF 05000000000000000900000001000000  403 1624505273         0        -1 text/html;charset=utf-8 3581/3581 GET http://cnn.com/
```

# Testing a cache hit (already called once above) 

```
kubectl exec $CURL_POD1 -n user1-dev -- curl -o /dev/null -s -w "%{http_code}\n" google.com
301
```

# Squid log

```
1624505480.529      0 10.131.0.17 TCP_MEM_HIT/301 870 GET http://google.com/ user1 HIER_NONE/- text/html
```
