Work in progress: Smeagol galore
============================

A lightweight version of cloudogu's git-based wiki system. Runs outside a cloudogu ecosystem.

```bash
mvn -f cas clean package
docker build -t smeagol-galore . 
# For TLS
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout ssl.key -out ssl.crt
docker run -it --rm -p 8080:8080 -p 8443:8443 -v $(PWD)/etc/cas.properties:/etc/cas/cas.properties -v $(PWD)/ssl.crt:/usr/local/tomcat/conf/ssl.crt -v $(PWD)/ssl.key:/usr/local/tomcat/conf/ssl.key  smeagol-galore
```

# Credentials
casuser::Mellon