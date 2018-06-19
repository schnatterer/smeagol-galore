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
scmadmin:scmadmin

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

- scmmmanger: Install and configure cas plugin and ?scm-webhook-plugin?
  https://github.com/cloudogu/scm/blob/master/Dockerfile
  - Set attributes same as in smeagol https://github.com/cloudogu/smeagol/blob/develop/src/main/java/com/cloudogu/smeagol/AccountService.java#L67
    set url to `/cas`?
  - Challenge: We don't have a hook that is called when scm is up. So can't use scm-script-plugin as in cloudogu/scm.
    We could try to install the cas plugin from docker file (similar to scm-script-plugin) and set defaults
- scmmanager with cas plugin: Login fails.
   - Cas logs:  `<saml1p:StatusCode Value="saml1p:Success"/>`
   - but scm: logs `[https-openssl-nio-8443-exec-9] ERROR de.triology.scm.plugins.cas.CasAuthenticationFilter - authentication failed`  
     No Stacktrace :-/: https://bitbucket.org/triologygmbh/scm-cas-plugin/src/a75de4c30890739d7d28668fdb64f5cf44e64499/src/main/java/de/triology/scm/plugins/cas/CasAuthenticationFilter.java?at=master&fileviewer=file-view-default#CasAuthenticationFilter.java-216
- make cas authenticate against scmm user base? Even when scmm itself uses cas, the rest api uses the local user base!
- create volume for .scm folder or whole user folder?
- scm plugin installs fail
- Which config files are required to be mounted on docker run? 
  deployerConfigContext.xml?
- Cleanup cas template (jetty, etc.), update deps & maven?
- Smeagol PR for executable war
- Create helm chart

 - change scm default PW on first start. EntryPoint.sh? And print to log?

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

* At the very end of `entrypoint.sh`: 
  ```bash
  export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n"
  catalina.sh jpda start
  ```
* Rebuild docker container.
* Start container with `-p8000:8000`
* Load sources for [SCM-Manager](https://github.com/sdorra/scm-manager) and related plugins, CAS from this repo and/or [smeagol](https://github.com/cloudogu/smeagol) into your IDE.
* Start debugger, e.g. in [IntelliJ](https://stackoverflow.com/a/6734028/1845976)

# never exit
while true; do sleep 10000; done


# Links

## Smeagol

* https://github.com/cloudogu/smeagol


## SCM

* [scm-cas-plugin](https://bitbucket.org/triologygmbh/scm-cas-plugin/src)
* [cloudogu/scm docker image](https://github.com/cloudogu/scm/blob/master/Dockerfile)


## CAS

* https://github.com/UniconLabs/simple-cas4-overlay-template/blob/master/pom.xml
* https://apereo.github.io/cas/4.0.x/index.html


