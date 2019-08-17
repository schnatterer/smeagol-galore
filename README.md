Smeagol galore
============================
[![Build Status](https://travis-ci.org/schnatterer/smeagol-galore.svg?branch=master)](https://travis-ci.org/schnatterer/smeagol-galore)
[![Docker Hub](https://images.microbadger.com/badges/image/schnatterer/smeagol-galore.svg)](https://hub.docker.com/r/schnatterer/smeagol-galore)

A lightweight version of [cloudogu's](https://cloudogu.com) git-based wiki system [smeagol](https://github.com/cloudogu/smeagol), the lightning-fast alternative to [gollum](https://github.com/gollum/gollum).

Runs without a full Cloudogu ecosystem, but still features
* Markdown,
* WYSIWYG Editors,
* [PlantUML](http://plantuml.com/),
* [SCM-Manager](https://www.scm-manager.org/) as Git backend,
* Single Sign On using [CAS](https://github.com/apereo/cas),
* everything deployed on an [Apache Tomcat](https://github.com/apache/tomcat) and 
* neatly packed into a docker image.

[![Diagram showing components and their relationships](http://www.plantuml.com/plantuml/svg/Z9BVIYCn58VlvocEkXSkE9Fw1oaYijsfYj1kfRNiXKWv9d4QEac69ACBuhjl9ZETjagbkJhjxvkJBoVvPHqQLyeyscFyHIWEwM0qxOzkfzFn0ERE5VQ248DlIIRSl7mkBJTKAyULIwYMXEQwP3ehIP6Zglh4otzYMnZXk2KIhUCcYlQ4edd9U6dozKr81LjYgKoAuF4z9ZbcEg_Hrlak7VtPpTUL1J9pkj8LFerVFD7wlfuadQIpuT7q9xw3rEgBPvip_bhrirwMBhZP3eODyOrRBJdnYgyxmuBDA1hsQG2J-_7Tm_LajnaOVEOvLmm93QTlPz5Eu3ZfaER7Xj5g6-AqfEXg3R_iGgW23Kf0O_GRl4S0gSwrWODEMD77EgGquu7vhGtZfY6Fpy-xNRP98dNQr2ZIHMPqgLY3dvpYAMDRcW3SQEM-ADJjfhPwa45Yln-kQX_G0WibmENbZxgykeA3bx22GVt1GpXv-C25ikBhQfCFgtg-iqawFBHK7e4luY4gpBZvkKGtmE5rxtOqE6oUkV-WBZx3DxtPNN-MziRzGuhs2DBUP1tvg8vQszvNbpiT3eBlygOhusNjdTyhl9e9nF4LD7l31LmpuU2lM8Yra4eVt787Orve6otXxoAVUKcVzKetvye9Yev77jyQhPgsnfuPSyMy1XEO6PGsQhFuSIuOu-gfRXT5KVrueJqaF9vr_vrroV7vq_zcwo39SH26ml2LdgGdmBl19Bx_aKQ9WPwakojcD_yovIyInOOuBLPIO0rm5QH5a6mDMC4Iu1P6hmDMI5PS1beXTMMbZIYs0eg6MG5EvBe2a20xLm0KsPO0u5W4M0Ba4c1oKg-3dDrfPfV1LX9f2if5K4hEPagx3B9R8e45G24MWVv_m7u5SWNedj0pAdfRav-1RBVMTaKapaWG-H7bdm3RcGEaHMJW_NYsopkmUckzFPan3CbypD8ho6ssjvRjGOncwNxSkzZ_0MnlxMwFGjXspAfR1tlxLhPH31arGf-WRhNzCiHUXsJhe6pVHEK0h5-20-HStmQ0fs0YZju6J92yjDaj2pf8Bi1vZ1ln0kXZoAQ8B01TWFFwxXaOm4vWLcwFl_V-EvaCpqfSW-8B0Aa4e8dLLZ1oeiUnpGHWJW5Kn1696u1pCLT0vCae4qJk3p2-4fbZ5BriEi7vrGJIb-yJXdLv0H3Q2Juq0Q2w221ga4zrCCXdy7Wt_ucdLpoZ_W80)](http://www.plantuml.com/plantuml/uml/Z9BVIYCn58VlvocEkXSkE9Fw1oaYijsfYj1kfRNiXKWv9d4QEac69ACBuhjl9ZETjagbkJhjxvkJBoVvPHqQLyeyscFyHIWEwM0qxOzkfzFn0ERE5VQ248DlIIRSl7mkBJTKAyULIwYMXEQwP3ehIP6Zglh4otzYMnZXk2KIhUCcYlQ4edd9U6dozKr81LjYgKoAuF4z9ZbcEg_Hrlak7VtPpTUL1J9pkj8LFerVFD7wlfuadQIpuT7q9xw3rEgBPvip_bhrirwMBhZP3eODyOrRBJdnYgyxmuBDA1hsQG2J-_7Tm_LajnaOVEOvLmm93QTlPz5Eu3ZfaER7Xj5g6-AqfEXg3R_iGgW23Kf0O_GRl4S0gSwrWODEMD77EgGquu7vhGtZfY6Fpy-xNRP98dNQr2ZIHMPqgLY3dvpYAMDRcW3SQEM-ADJjfhPwa45Yln-kQX_G0WibmENbZxgykeA3bx22GVt1GpXv-C25ikBhQfCFgtg-iqawFBHK7e4luY4gpBZvkKGtmE5rxtOqE6oUkV-WBZx3DxtPNN-MziRzGuhs2DBUP1tvg8vQszvNbpiT3eBlygOhusNjdTyhl9e9nF4LD7l31LmpuU2lM8Yra4eVt787Orve6otXxoAVUKcVzKetvye9Yev77jyQhPgsnfuPSyMy1XEO6PGsQhFuSIuOu-gfRXT5KVrueJqaF9vr_vrroV7vq_zcwo39SH26ml2LdgGdmBl19Bx_aKQ9WPwakojcD_yovIyInOOuBLPIO0rm5QH5a6mDMC4Iu1P6hmDMI5PS1beXTMMbZIYs0eg6MG5EvBe2a20xLm0KsPO0u5W4M0Ba4c1oKg-3dDrfPfV1LX9f2if5K4hEPagx3B9R8e45G24MWVv_m7u5SWNedj0pAdfRav-1RBVMTaKapaWG-H7bdm3RcGEaHMJW_NYsopkmUckzFPan3CbypD8ho6ssjvRjGOncwNxSkzZ_0MnlxMwFGjXspAfR1tlxLhPH31arGf-WRhNzCiHUXsJhe6pVHEK0h5-20-HStmQ0fs0YZju6J92yjDaj2pf8Bi1vZ1ln0kXZoAQ8B01TWFFwxXaOm4vWLcwFl_V-EvaCpqfSW-8B0Aa4e8dLLZ1oeiUnpGHWJW5Kn1696u1pCLT0vCae4qJk3p2-4fbZ5BriEi7vrGJIb-yJXdLv0H3Q2Juq0Q2w221ga4zrCCXdy7Wt_ucdLpoZ_W80)

**NOTE**: This version of smeagol-galore uses a SNAPSHOT version of SCM-Manager v2. Breaking changes might occurr!

**TODO SCMv2**

* Make initial repo be picked up by SCMv2

# Table of contents

<!-- Update with `doctoc --notitle README.md`. See https://github.com/thlorenz/doctoc -->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Usage](#usage)
  - [Getting started](#getting-started)
  - [Persist state](#persist-state)
  - [Custom Certificate](#custom-certificate)
  - [Create more wikis](#create-more-wikis)
  - [Credentials](#credentials)
  - [Configuration](#configuration)
  - [Kubernetes](#kubernetes)
- [Troubleshooting](#troubleshooting)
  - [Extend Log output](#extend-log-output)
    - [SCM-Manager](#scm-manager)
  - [Debugging](#debugging)
- [Links](#links)
  - [SCM](#scm)
  - [CAS](#cas)
- [Building](#building)
- [TODOs](#todos)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Usage 

## Getting started 

```bash
docker run -p 8443:8443 schnatterer/smeagol-galore:0.2.0-SNAPSHOT
```

Note that
 
* SCM-Manager installs plugins via the internet on first startup, so it might take some time.
  You can choose which plugins are installed by editing `plugin-config.yml`, e.g. by mounting your own version into the
  container: `- v your-plugin-config.yml:/etc/scm/plugin-config.yml`
* A self-signed certificate will be created on startup.
  These will result in warnings in your browser.  
  See bellow for custom certificates.
* Smeagol galore will be available on [https://localhost:8443](https://localhost:8443) (and via `/smeagol`).  
  SCM-Manager will be available on [https://localhost:8443/scm](https://localhost:8443/scm).
* Default user/pw: `admin/admin` (see bellow for custom credentials)

## Persist state 

Mount SCMM Volume to persist your repos/wikis: `-v $(pwd)/dev/scm:/home/tomcat/.scm `.
This will also persist SCMM plugins, so the second start will be much faster. 

```bash
docker run --rm --name smeagol-galore -p 8443:8443 -v $(pwd)/dev/scm:/home/tomcat/.scm schnatterer/smeagol-galore:0.2.0-SNAPSHOT
``` 

## Custom Certificate

The self-signed certificate is only a valid option for trying out and development.
In production you should provide a proper certificate, which can be done by mounting a java keystore like so: 
`-v $(pwd)/dev/keystore.jks:/usr/local/tomcat/conf/keystore.jks`.

Note that smeagol, cas and SCMM communicate with each other via HTTPS.
If you're certificate is not trusted by the JVM you should add it to the trust store and then mount it like so: 
`-v $(pwd)/dev/cacerts:/usr/lib/jvm/java-1.8-openjdk/jre/lib/security/cacerts`.

See [entrypoint.sh](entrypoint.sh) for an example.


## Create more wikis

Note that the git arg `-c http.sslVerify=false ` is only necessary for testing with a self-signed cert .
If you use an official TLS cert this won't be necessary. 

* Go to https://localhost:8443/scm 
* Log in as administrator
* Create a git repo
* Clone into git wiki, e.g. for localhost: `git -c http.sslVerify=false clone https://admin@localhost:8443/scm/git/test`
* Add empty `.smeagol.yml` file: `touch .smeagol.yml && git add .smeagol.yml && git commit -m 'Create smeagol wiki'`
* Push, e.g. for localhost: `git -c http.sslVerify=false push`
* Go to https://localhost:8443/smeagol

All in one:

```bash
git -c http.sslVerify=false clone https://admin@localhost:8443/scm/git/test
cd test
touch .smeagol.yml
git add .smeagol.yml
git commit -m 'Creates smeagol wiki'
git -c http.sslVerify=false push --set-upstream origin master
```

## Credentials

Default user/pw: `admin/admin`

Credentials defined in `/etc/cas/users.txt` and `/etc/cas/attributes.xml`. Custom ones can be mounted into the container like so for example: `-v $(pwd)/dev/users.txt:/etc/cas/users.txt`.

See [users.txt](cas/etc/cas/users.txt) and [attributes.xml](cas/etc/cas/attributes.xml).

CAS has "pluggable authentication support (LDAP, database, X.509, 2-factor)" see [CAS 4 docs](https://apereo.github.io/cas/4.0.x/index.html).
Get started at [deployerConfigContext.xml](cas/src/main/webapp/WEB-INF/deployerConfigContext.xml)


## Configuration

Via Environment Variables:

* Set the name of SCM-Manager's `ADMIN_GROUP`
* Set your Fully Qualified Domain name (including Port) - `FQDN`  
  Note that the smeagol galore container must be able to resolve this address as well, 
  because the webb apps communicate with each other (smeagol -> cas, smeagol -> scm, scm -> cas).
  You can try this out locally, by adding the following entry to your `/etc/hosts`: `127.0.0.1 smeagol` and then passing 
  the following parameters to the container: `-v /etc/hosts:/etc/hosts -e FQDN=smeagol:8443`. You can then reach smeagol
  at `https://smeagol:8443`.
* `-e DEBUG=true` exposes port 8000 as Tomcat debug port
* `EXTRA_JVM_ARGUMENTS`, set e.g. `-XmX` for tomcat process

The container is run as with UID and GID = 1000.
If you want to run it as a different user you pass `-u` param when running the container.
However, you should make sure that that the user exists (e.g. mount `/etc/passwd`).
In order to get permissions on `/usr/local/tomcat` your user should be member of group 1000.

Another option is to build your own image and set `--build-arg USER_ID` and `GROUP_ID` to your liking.


## Kubernetes

For an examples on how to deploy to kubernetes see folder `k8s`.

It does not set a specific namespace, so set a namespace of your choice in you kubeconfig and deploy  with
`kubectl apply -f k8s`.
Note that this contains a whitelisting network policy for incoming traffic into the namespace allowing only inbound 
traffic to smeagol-galore ([networkPolicy.yaml](k8s/networkPolicy.yaml)).

The example [deployment.yaml](k8s/deployment.yaml) contains 
* Setting resource requests & limits
* Defining readiness and liveness probes
* Security: Run as non-privileged user, don't mount service account token, use custom service account 
  ([serviceAccount.yaml](k8s/serviceAccount.yaml)).
* Setting custom FQDN
* Use persistent storage ([pvc.yaml](k8s/pvc.yaml))
* Defining custom user and attributes ([configmap.yaml](k8s/configmap.yaml) and [secret.yaml](k8s/secret.yaml) - in
  this example we set up a user `arthur` with his password `towel`).
* Defining custom self signed cert ([secret.yaml](k8s/secret.yaml)).


# Troubleshooting

## Debugging

* Start container with `-p8000:8000 -e DEBUG=true`
* Load sources for [SCM-Manager](https://github.com/sdorra/scm-manager) and related plugins, CAS from this repo and/or [smeagol](https://github.com/cloudogu/smeagol) into your IDE.
* Start debugger, e.g. in [IntelliJ](https://stackoverflow.com/a/6734028/1845976) on port 8000

# Links

[Unidata/tomcat-docker: Security-hardened Tomcat container](https://github.com/Unidata/tomcat-docker)

## SCM

* [scm-cas-plugin](https://bitbucket.org/scm-manager/scm-cas-plugin/src/master/)
* [cloudogu/scm docker image](https://github.com/cloudogu/scm/blob/master/Dockerfile)

## CAS

* [Cas 4 Overlay example](https://github.com/UniconLabs/simple-cas4-overlay-template/blob/master/pom.xml)
* [CAS 4 code](https://github.com/apereo/cas/tree/v4.0.7)
* [CAS 4 docs](https://apereo.github.io/cas/4.0.x/index.html)

# Building

`docker build -t smeagol-galore .`

* Optionally, you can choose your own PlantUML server like so: `--build-arg PLANTUMLSERVER="https://[...]/png/"`


# TODOs

- Convert to a more 12-factor-like app using multiple containers and docker-compose
- Use PKCMS12 instead of java keystore in tomcat and for self signed.
  An idea, using openssl (which is not present in container, yet):
  ```bash
    # We could change a pks12 keystore like so, for example
    openssl req -newkey rsa:2048 -x509 -keyout cakey.pem -out cacert.pem \
       -subj '/CN=localhost/OU=Unknown/O=Unknown/L=Unknown/S=Unknown/C=Unknown' -days 3650
    openssl pkcs12 -export -in cacert.pem -inkey cakey.pem -out keystore.jks -name "localhost"
    ```
- Create helm chart
- How to run behind proxy (HTTP/S, certs, Proxy config, etc.)?

