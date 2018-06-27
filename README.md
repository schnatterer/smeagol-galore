Smeagol galore
============================

A lightweight version of [cloudogu's](https://cloudogu.com) git-based wiki system [smeagol](https://github.com/cloudogu/smeagol) the lighning-fast alternative to [gollum](https://github.com/gollum/gollum).

Runs without a full cloudogu ecosystem, but still features
* Markdown,
* WYSIWYG Editors,
* PlantUML,
* SCM-Manager,
* Single Sign On using CAS,
* everything deployed on a tomcat and 
* neatly packed into a docker image.

# Get started 

## Run the container 

```bash
docker build -t smeagol-galore . 

docker run -it --rm -p 8080:8080 -p 8443:8443 \
    -v $(PWD)/dev/cacerts:/usr/lib/jvm/java-1.8-openjdk/jre/lib/security/cacerts  -v $(PWD)/dev/keystore.jks:/usr/local/tomcat/conf/keystore.jks  \
    -v $(PWD)/dev/scm:/user/tomcat/.scm \
    smeagol-galore
```

Note that SCM-Manager installs plugins via the internet on first startup.

## Create self signed TLS certs and add to truststore / cacerts for local development

https://burcakulug.wordpress.com/2017/09/09/how-to-make-java-and-tomcat-docker-containers-to-trust-self-signed-certificates/

```bash
docker run -it -v $(PWD)/dev:/cacerts-test openjdk:8u102-jre
cd /cacerts-test; cp /etc/ssl/certs/java/cacerts .
# In order to authenticate via scm-cas-plugin, we need to provide a subjectAltName otherwise we'll encounter 
# ClientTransportException: HTTP transport error: javax.net.ssl.SSLHandshakeException: java.security.cert.CertificateException: No subject alternative names present
# See https://stackoverflow.com/a/84441845976863/
keytool -genkey -alias localhost -keyalg RSA -keypass changeit -storepass changeit -keystore keystore.jks -ext san=ip:127.0.0.1 -ext san=dns:localhost
keytool -export -alias localhost -storepass changeit -file server.cer -keystore keystore.jks

keytool -import -v -trustcacerts -alias localhost -file server.cer -keystore cacerts -keypass changeit -storepass changeit
# Check successful
keytool -list -alias localhost -keystore cacerts -storepass changeit
```

## Credentials

Are defined in `/etc/cas/users.txt` and `/etc/cas/attributes.xml`. Custom ones can be mounted into the container like so for example: `-v $(PWD)/dev/users.txt:/etc/cas/users.txt`.

Default: `admin:admin`

See [users.txt](cas/etc/cas/users.txt) and [attributes.xml](cas/etc/cas/attributes.xml).

CAS has "pluggable authentication support (LDAP, database, X.509, 2-factor)" see [CAS 4 docs](https://apereo.github.io/cas/4.0.x/index.html).
Get started at [deployerConfigContext.xml](cas/src/main/webapp/WEB-INF/deployerConfigContext.xml)


## Environment Variables

* You can overwrite the user and group ID that that starts the server process by passing `-e USER_ID 1042 -e GROUP_ID 1042`. Be default UID and GID `1000` are used.
* Set the name of SCM-Manager's `ADMIN_GROUP`
* Set your Fully Qualified Domain name (including Port) - `FQDN`
* `-e DEBUG=true` exposes port 8000 as Tomcat debug port

## Create wiki

* Go to https://localhost:8443/scm 
* Log in as administrator
* Create a git repo
* Clone into git wiki, e.g. for localhost: `git -c http.sslVerify=false clone https://admin@localhost:8443/scm/git/test`
* Add empty `.smeagol.yml` file
* Push, e.g. for localhost: `git -c http.sslVerify=false push`
* Go to https://localhost:8443/smeagol

# Troubleshooting

## Extend Log output

### SCM-Manager

* Copy `logback.xml` for [SCM-Manager](https://github.com/sdorra/scm-manager/blob/one.dot.x/scm-webapp/src/main/resources/logback.default.xml)
* Increase logging for SCM-Manager and/or plugins. E.g. for SCM-Manager
  ```xml
    <logger name="sonia.scm" level="TRACE" />
  ```
* Run Container with `-v $(PWD)/dev/scm/logback.xml:/usr/local/tomcat/webapps/scm/WEB-INF/classes/logback.xml`

## Debugging

* Start container with `-p8000:8000 -e DEBUG=true`
* Load sources for [SCM-Manager](https://github.com/sdorra/scm-manager) and related plugins, CAS from this repo and/or [smeagol](https://github.com/cloudogu/smeagol) into your IDE.
* Start debugger, e.g. in [IntelliJ](https://stackoverflow.com/a/6734028/1845976) on port 8000

# Links

## SCM

* [scm-cas-plugin](https://bitbucket.org/triologygmbh/scm-cas-plugin/src)
* [cloudogu/scm docker image](https://github.com/cloudogu/scm/blob/master/Dockerfile)

## CAS

* [Cas 4 Overlay example](https://github.com/UniconLabs/simple-cas4-overlay-template/blob/master/pom.xml)
* [CAS 4 code](https://github.com/apereo/cas/tree/v4.0.7)
* [CAS 4 docs](https://apereo.github.io/cas/4.0.x/index.html)

# TODOs

- Write FQDN Env Var to cas config files, smeagol.yml, scm cas plugin, etc.?

- Create helm chart (use draft?)
 
- Convert to a more 12-factor-like app using multiple containers and docker-compose
