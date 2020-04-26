Smeagol Galore examples using docker-compose
====


# Table of contents

<!-- Update with `doctoc --notitle README.md`. See https://github.com/thlorenz/doctoc -->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Simplest docker-compose example](#simplest-docker-compose-example)
- [General example, showcasing several options](#general-example-showcasing-several-options)
- [Internal network](#internal-network)
- [Ports 80 / 443](#ports-80--443)
- [Creating certs for internal communication](#creating-certs-for-internal-communication)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## Simplest docker-compose example

Only skips plugin install for faster startup. 
 
See [`docker-compose-simple.yaml`](docker-compose-simple.yaml).

Note that the image is defined in `.env` to facilitate replacement during testing.
In a production setup this would not be necessary. 

Start the app with 

```bash
docker-compose -f docker-compose-simple.yaml up -d
```

Smeagol galore can be reached via on `https://localhost:8443`.


## General example, showcasing several options 

This example shows some options and features for smeagol-galore, implemented in the 
[`docker-compose-general.yaml`](docker-compose-general.yaml).

* Adds a non-admin user
* Installs only the very minimal set of plugins needed
* Enables verbose log output
* Increases session timeout  / token expiration (login less often)
* Mounts a custom certificate and CA certs. 
* Exposes SSH Port for Git Operations on SCM-Manager via SSH

A setup like this should work fine when used behind a reverse proxy. See bellow for details.

In addition, the example implements a number of good practices for docker containers:

* Config files mounted `read-only` enforcing integrity of the config files.
* `security-opt=no-new-privileges` avoids privilege escalation.
* `restart` to provide better uptime in case of error.
* store wiki (git repo) in a docker volume.
* dedicated network, blocking access to other containers on the host.  
  Note that using an internal network will stop the plugins from being installed.  
* a `read-only` root file system, enforcing integrity of the application files.  
  For this to work all folders that are written to at runtime are mounted as volumes. The ones containing temporary 
  data is mounted as `tempfs`, an in-memory FS cleaned automatically and high throughput.  
  Note that for now, `read-only` will only work when mounting your own certificates, because otherwise the app creates 
  and tries to create its own, but is not allowed, because the folders, when mounted as volume, are owned by root.  
  See [here](#creating-certs-for-internal-communication) how to generate certs.
* Drops all capabilities. Smeagol-galore does not need any and it decreases the attack surface of the container.

From a security perspective, one thing could be further improved, though: block outgoing traffic. As this is not 
straight forward with compose, it is realized in a [separate example](#internal-network). 
 
Start the app with 

```bash
docker-compose -f docker-compose-general.yaml up -d
```

Smeagol galore can be reached via on `https://localhost:8443`.


## Internal network 

This example uses the same security options as [`docker-compose-general.yaml`](docker-compose-general.yaml), but
additionally runs in an internal network. 

In production, the network could be set up as `internal`. This is more secure, because an attacker wouldn't be able
to access the internet, nor the host's network. There are some challenges, though:

* Downloading plugins in SCM-Manager startup will fail.
* With an internal network, port bindings are ignored.
 * The simplest option is to use the IP Address (in our example `172.1.2.2`) as `FQDN`.   
 * In production, with an `FQDN` such as `smeagol.com`, this `FQDN` must also be set as `hostname`.
   Otherwise, `smeagol` and `scm-manager` will not be able to validate authentication against `cas`.
   In addition, when the `FQDN` does not contain a port, the `HTTPS_PORT` env var must be set to 443. 
   See [other example](#ports-80--443).
 * This can be tested locally, by using an `FQDN` such as  `smeagol` and adding the following to your 
     `/etc/hosts`: `172.1.2.2   smeagol`.  
    For this to work we need to [generate certificates](#creating-certs-for-internal-communication).

Start the app with 

```bash
# Example 1: Start app without dns name
docker-compose -f docker-compose-internal-network.yaml up -d
# Smeagol galore can be reached on `https://172.1.2.2:8443`.

# Example 2: Start app with dns name
docker-compose -f docker-compose-internal-network-hostname.yaml up -d
# Add "smeagol" entry to your /etc/hosts and access via browser
# Smeagol galore can be reached on https://smeagol:8443
```

## Ports 80 / 443

In some use cases it might be necessary to listen to well-known ports 80 and 443 instead of the default 8080 and 8443.

* When running smeagol without reverse proxy and want to get rid of explicitly mentioned ports, e.g `https://example.com`  
  instead of `https://example.com:8443` or
* When running behind a reverse proxy but with an internal network, so inside the container `smeagol` is able to connect
  to `cas` via the `hostname` that is set to the value as `FQDN` (that is, using internal network without leaving the 
  container).

Two security options are incompatible with binding to well-known ports: 
* `security_opt: [ no-new-privileges ]`
* needs capability `NET_BIND_SERVICE`

Start the app with 

```bash
docker-compose -f docker-compose-80-443.yaml
```

Smeagol galore can be reached via on `https://172.1.2.2`.


## Creating certs for internal communication

You still might need a self signed cert, which is used for internal communication.
You can easily create it be starting a throw-away smeagol-galore container and copy the 
 `/config/certs` and `/opt/bitnami/java/lib/security/cacerts` to your config directory. 

For example like so:

```bash
# The ip address of the container is also added to the cert, so you might want to specify it.
# Eg, for this example it was created as follows
docker network create --subnet 172.1.2.0/24 myNet

CONTAINER=$(\
    docker run --rm -d \
      -e CERT_VALIDITY_DAYS=3650 \
      -e FQDN=smeagol:8443 \
      --net myNet --ip 172.1.2.2 \
      smeagol
)
sleep 5
docker cp "${CONTAINER}:/config/certs/" .
docker cp "${CONTAINER}:/opt/bitnami/java/lib/security/cacerts" certs

docker stop "${CONTAINER}"
rm certs/ca.crt.srl
# Allow reading via group (root, as in container)
sudo chown -R :0 certs/
sudo chmod -R 440 certs/*

docker network rm myNet
```