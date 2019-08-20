Smeagol Galore example using docker-compose
====

This example shows some options and features for smeagol-galore, implemented in the 
[`docker-compose.yaml`](docker-compose.yaml).

* Adds an unprivileged user
* Installs only the very minimal set of plugins needed
* Enables verbose log output

In addition, it implements a number of good practices for docker containers:

* Config files mounted `read-only` enforcing integrity of the config files.
* `security-opt=no-new-privileges` avoids privilege escalation.
* `restart` to provide better uptime in case of error.
* store wiki (git repo) in a docker volume.
* dedicated network, blocking access to other containers on the host
  Note: That using an internal network will stop the plugins from being installed.  

Some things could be further improved, though:

* It would even better to use a `read-only` root file system enforcing integrity of the application files.  
  However, creating the certificate writes to the file system, which causes a number of challenges.  
  See comments in `docker-compose.yaml` for details.
* Using the internal IP `172.1.2.2` without port binding would be more secure. However, setting a numeric `FQDN` does 
  not work with the Tools used for creating the certificate.  
  This could be done using a reverse proxy that serves a domain, 
  or by setting a `FQDN` such as `smeagol` and adding the following to your `/etc/hosts`: `172.1.2.2   smeagol`.  
  This example should run out of the box, so we simply this here.

Start with 

```bash
docker-compose up -d
```

Gollum galore can be reached vid on `https://localhost:8443`.
