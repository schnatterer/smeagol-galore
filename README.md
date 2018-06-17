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
- Users:
 - change scm default PW on first start. EntryPoint.sh? And print to log?
 - How to authorize user created in CAS? Create Group? 
- Which config files are required to be mounted on docker run? 
  deployerConfigContext.xml?
- ...
- Cleanup cas template (jetty, etc.), update deps & maven?
- Smeagol PR for executable war
- Create helm chart

# Links

## Smeagol

* https://github.com/cloudogu/smeagol


## SCM

* [scm-cas-plugin](https://bitbucket.org/triologygmbh/scm-cas-plugin/src)
* [cloudogu/scm docker image](https://github.com/cloudogu/scm/blob/master/Dockerfile)


## CAS

* https://github.com/UniconLabs/simple-cas4-overlay-template/blob/master/pom.xml
* https://apereo.github.io/cas/4.0.x/index.html


