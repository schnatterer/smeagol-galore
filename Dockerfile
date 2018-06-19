#TODO cas build stage

# Download and cache webapps
FROM alpine:3.7 as downloader
ENV SCM_VERSION=1.54

RUN set -x && \
  apk add --no-cache --update zip unzip && \
  mkdir /webapps && \
  wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/schnatterer/smeagol/33e358d427/smeagol-33e358d427.war && \
  wget -O /tmp/scm.war https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm//scm-webapp/${SCM_VERSION}/scm-webapp-${SCM_VERSION}.war && \
  unzip /tmp/scm.war -d /webapps/scm 

# Set plantuml.com as plantuml renderer. Alternative would be to deploy plantuml
# "Fix" executable war (which seems to confuse jar & zip utilities)
RUN set -x && \
  zip -F /tmp/smeagol-exec.war --out /tmp/smeagol.war && \
  unzip /tmp/smeagol.war -d /webapps/smeagol && \
  sed -i "s/rendererURL\:\"\/plantuml\/png\//rendererURL\:\"http:\/\/www.plantuml.com\/plantuml\/png\//" "$(ls /webapps/smeagol/WEB-INF/classes/static/static/js/main*.js)"

COPY cas/target/cas.war /webapps/cas.war

FROM tomcat:9.0.8-jre8-alpine

RUN \
  apk add --no-cache --update su-exec && \
  mkdir /home/tomcat
  # TODO add umask 007 or 077?
  #umask "077"

COPY --from=downloader /webapps/ /usr/local/tomcat/webapps/

# TODO consolidate/optimize COPY stages
# TODO set favicon

# Tomcat Config (TLS & root URL redirect)
COPY tomcat /usr/local/tomcat
# Smeagol config
COPY smeagol/application.yml /usr/local/tomcat/application.yml
COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]