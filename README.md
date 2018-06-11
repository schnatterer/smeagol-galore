Work in progress: Smeagol galore
============================

A lightweight version of cloudogu's git-based wiki system. Runs outside a cloudogu ecosystem.

```bash
mvn -f cas clean package
docker build -t smeagol-galore . 

docker run -it --rm -p 8080:8080 -p 8443:8443 -v $(PWD)/cas/etc/cas.properties:/etc/cas/cas.properties \
    -v $(PWD)/dev/cacerts:/usr/lib/jvm/java-1.8-openjdk/jre/lib/security/cacerts  -v $(PWD)/dev/keystore.jks:/usr/local/tomcat/conf/keystore.jks  \
    -v $(PWD)/dev/scm:/root/.scm \
    smeagol-galore
```

# Credentials
casuser::Mellon

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