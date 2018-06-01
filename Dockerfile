#TODO cas build stage

FROM tomcat:9.0.8-jre8-alpine

COPY target/cas.war /usr/local/tomcat/webapps/cas.war

COPY smeagol/application.yml /usr/local/tomcat/application.yml

RUN \
  wget -O  /usr/local/tomcat/webapps/smeagol.war https://jitpack.io/com/github/schnatterer/smeagol/33e358d427/smeagol-33e358d427.war \
  && wget -O /usr/local/tomcat/webapps/scm.war https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm//scm-webapp/1.60/scm-webapp-1.60.war 