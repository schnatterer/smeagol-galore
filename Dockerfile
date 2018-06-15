#TODO cas build stage

# Download and cache webapps
FROM alpine:3.7 as downloader
RUN \
  apk add --update zip unzip \
  && mkdir /webapps && cd webapps \
  && wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/schnatterer/smeagol/33e358d427/smeagol-33e358d427.war \
  && wget -O scm.war https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm//scm-webapp/1.60/scm-webapp-1.60.war  \
  # Set plantuml.com as plantuml renderer. Alternative would be to deploy plantuml
  # "Fix" executable war (which seems to confuse jar & zip utilities)
  && zip -F /tmp/smeagol-exec.war --out /tmp/smeagol.war \
  && unzip /tmp/smeagol.war -d /webapps/smeagol \
  && sed -i "s/rendererURL\:\"\/plantuml\/png\//rendererURL\:\"http:\/\/www.plantuml.com\/plantuml\/png\//" "$(ls smeagol/WEB-INF/classes/static/static/js/main*.js)" 

FROM tomcat:9.0.8-jre8-alpine

# Webapps
COPY cas/target/cas.war /usr/local/tomcat/webapps/cas.war
COPY --from=downloader /webapps/ /usr/local/tomcat/webapps/

# Tomcat Config (TLS & root URL redirect)
COPY tomcat /usr/local/tomcat
# Smeagol config
COPY smeagol/application.yml /usr/local/tomcat/application.yml