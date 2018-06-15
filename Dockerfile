#TODO cas build stage

# Download and cache webapps
FROM alpine:3.7 as downloader
RUN \
  mkdir /webapps \
  && wget -O  /webapps/smeagol.war https://jitpack.io/com/github/schnatterer/smeagol/33e358d427/smeagol-33e358d427.war \
  && wget -O /webapps/scm.war https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm//scm-webapp/1.60/scm-webapp-1.60.war 

#FROM unidata/tomcat-docker:8.5
FROM tomcat:9.0.8-jre8-alpine

# Webapps
COPY cas/target/cas.war /usr/local/tomcat/webapps/cas.war
COPY --from=downloader /webapps/ /usr/local/tomcat/webapps/

# Tomcat Config (TLS & root URL redirect)
COPY tomcat /usr/local/tomcat
# Smeagol config
COPY smeagol/application.yml /usr/local/tomcat/application.yml