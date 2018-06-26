Work in progress: Smeagol galore
============================

A lightweight version of cloudogu's git-based wiki system. Runs outside a cloudogu ecosystem.

```bash
mvn -f cas clean package
docker build -t smeagol-galore . 

docker run -it --rm -p 8080:8080 -p 8443:8443 -v $(PWD)/cas/etc/cas.properties:/etc/cas/cas.properties \
    -v $(PWD)/dev/cacerts:/usr/lib/jvm/java-1.8-openjdk/jre/lib/security/cacerts  -v $(PWD)/dev/keystore.jks:/usr/local/tomcat/conf/keystore.jks  \
    -v $(PWD)/dev/scm:/user/tomcat/.scm \
    smeagol-galore
```

You can overwrite the user and group ID that that starts the server process by passing `-e USER_ID 1042 -e GROUP_ID 1042`. Be default UID and GID `1000` are used.

# Credentials
admin:admin

# Create self signed TLS certs and add to truststore / cacerts for local development

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

# TODOs
- make cas authenticate against scmm user base? Even when scmm itself uses cas, the rest api uses the local user base!

- Make hostname configurable (overwrite in entrypoint in cas, smeagol.yml, scm cas plugin, etc.?)
- Which config files are required to be mounted on docker run? 
  - deployerConfigContext.xml? (use xml for attributes?) / cas.properties
  - or can we include them in image and adapt e.g. hostname and pw change url in
   entrypoint?
- Cleanup cas template (jetty, etc.), update deps & maven?
- Readme: Getting started: 
  - Needs internet access for installing cas plugin on first start
  - How to create first wiki
- Create helm chart (use draft?)
- ...
 
 - set favicon
 - Install scm-webhook-plugin and configure for smeagol? Still needed for smeagol 0.5.0?
- TODOs in dockerfile?

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

## Smeagol

* https://github.com/cloudogu/smeagol


## SCM

* [scm-cas-plugin](https://bitbucket.org/triologygmbh/scm-cas-plugin/src)
* [cloudogu/scm docker image](https://github.com/cloudogu/scm/blob/master/Dockerfile)


## CAS

* [Cas 4 Overlay example](https://github.com/UniconLabs/simple-cas4-overlay-template/blob/master/pom.xml)
* [CAS 4 code](https://github.com/apereo/cas/tree/v4.0.7)
* [CAS 4 docs](https://apereo.github.io/cas/4.0.x/index.html)


