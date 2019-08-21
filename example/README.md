Smeagol Galore example using docker-compose
====

This example shows some options and features for smeagol-galore, implemented in the 
[`docker-compose.yaml`](docker-compose.yaml).

* Adds an non-admin user
* Installs only the very minimal set of plugins needed
* Enables verbose log output
* Increases session timeout  / token expiration (login less often)
* Mounts custom certificate (via keystore) and CA certs. 

A setup like this should work fine when used behind a reverse proxy.

In addition, the example implements a number of good practices for docker containers:

* Config files mounted `read-only` enforcing integrity of the config files.
* `security-opt=no-new-privileges` avoids privilege escalation.
* `restart` to provide better uptime in case of error.
* store wiki (git repo) in a docker volume.
* dedicated network, blocking access to other containers on the host.  
  Note that using an internal network will stop the plugins from being installed.  
* a `read-only` root file system, enforcing integrity of the application files.  
  For this to work all folders that are written to at runtime are mounted as volumes. The ones containing temporary 
  data are mounted as `tempfs`, an in-memory FS cleaned automatically and high throughput.  
  Note that for now, `read-only` will only work when mounting your own keystore, because otherwise the app creates and 
  tries to write its own keystore, but is not allowed, because the folders, when mounted as volume, are owned by root.

Some things could be further improved, though:

In production, the network should be set up as `internal`. This is more secure, because an attacker wouldn't be able
to access the internet, nor the host's network. However,
 
* this will also ignore  port bindings leaving us to use the IP Address `172.1.2.2` as `FQDN`. However, setting a
  numeric `FQDN` does not work with the Tools used for creating the certificate.  
  This could be done using a reverse proxy that serves a domain, or by setting a `FQDN` such as `smeagol` and adding
  the following to your `/etc/hosts`: `172.1.2.2   smeagol`.    
* Also downloading plugins on startup would fail.
* This example should run out of the box, so we simplify this here.

Start the app with 

```bash
docker-compose up -d
```

Smeagol galore can be reached vid on `https://localhost:8443`.