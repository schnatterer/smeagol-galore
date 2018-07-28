# Define maven version for all stages
FROM maven:3.5.4-jdk-8-alpine as maven

FROM maven as mavencache
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn
ADD cas/pom.xml /cas/pom.xml
WORKDIR /cas
RUN mvn dependency:resolve dependency:resolve-plugins

FROM maven as mavenbuild
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn 
COPY --from=mavencache /mvn/ /mvn/
ADD cas/ /cas/
WORKDIR /cas
RUN set -x && \
  mvn package


# Download and cache webapps
FROM alpine:3.7 as downloader
ENV SCM_VERSION=1.54 \
    SCM_SCRIPT_PLUGIN_VERSION=1.6 \
    GROOVY_VERSION=2.4.12 \
    SMEAGOL_VERSION=v0.5.2 \
    CATALINA_HOME=/dist/usr/local/tomcat/webapps

COPY --from=mavenbuild /cas/target/cas.war /tmp/cas.war

RUN set -x && \
  apk add --no-cache --update zip unzip curl && \
  mkdir -p ${CATALINA_HOME} && \
  wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war && \
  wget -O /tmp/scm.war https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm//scm-webapp/${SCM_VERSION}/scm-webapp-${SCM_VERSION}.war && \
  unzip /tmp/scm.war -d ${CATALINA_HOME}/scm && \
  unzip /tmp/cas.war -d ${CATALINA_HOME}/cas

# "Install" scm script plugin
RUN set -x && \
  curl -Lks http://repo1.maven.org/maven2/org/codehaus/groovy/groovy-all/${GROOVY_VERSION}/groovy-all-${GROOVY_VERSION}.jar -o ${CATALINA_HOME}/scm/WEB-INF/lib/groovy-all-${GROOVY_VERSION}.jar && \
  curl -Lks http://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm/plugins/scm-script-plugin/${SCM_SCRIPT_PLUGIN_VERSION}/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.jar -o ${CATALINA_HOME}/scm/WEB-INF/lib/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.jar

# Set plantuml.com as plantuml renderer. Alternative would be to deploy plantuml
# "Fix" executable war (which seems to confuse jar & zip utilities)
ARG PLANTUMLSERVER="http://www.plantuml.com/plantuml/png/"
RUN set -x && \
  zip -F /tmp/smeagol-exec.war --out /tmp/smeagol.war && \
  unzip /tmp/smeagol.war -d ${CATALINA_HOME}/smeagol && \
  sed -i "s#rendererURL:\"/plantuml/png/#rendererURL:\"${PLANTUMLSERVER}#g" "$(ls ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/static/js/main*.js)"

# Aggregate /dist to copied into one layer of the final image
# CAS config
COPY cas/etc/ /dist/etc/
# SCM config
COPY scm /dist
# Tomcat Config (TLS & root URL redirect)
COPY tomcat /dist/usr/local/tomcat
# Smeagol config
COPY smeagol/application.yml /dist/usr/local/tomcat/application.yml
COPY entrypoint.sh /dist


# Build final image
# Before switching to tomcat 9 make sure there is a solution for the permission proble with aufs:
# https://github.com/docker-library/tomcat/issues/35
FROM tomcat:8.0.53-jre8-alpine
ARG USER_ID="1000"
ARG GROUP_ID="1000"

COPY --from=downloader /dist /

RUN \
  # Delete tomcat default apps
  cd ${CATALINA_HOME}/webapps/ && rm -rf docs examples manager host-manager && \
  # Delete all of ROOT app except index
  find ${CATALINA_HOME}/webapps/ROOT/* ! -path . ! -name index.* -delete && \
  mkdir -p /home/tomcat/.scm  && \
  # Add umask -> New files are only accessible to user and group
  umask "007" && \
  # Create tomcat user & group
  addgroup -g ${GROUP_ID} -S tomcat && \
  adduser -u ${USER_ID} -S tomcat -G tomcat && \
  chown -R tomcat:tomcat ${CATALINA_HOME} && \
  chown -R tomcat:tomcat /home/tomcat && \
  chown -R tomcat:tomcat /etc/cas && \
  chown -R tomcat:tomcat /etc/ssl/certs/java/cacerts && \
  chmod 774 /etc/ssl/certs/java/cacerts && \
  chmod -R 770 /home/tomcat && \
  chmod 400 ${CATALINA_HOME}/conf/*

VOLUME /home/tomcat/.scm

EXPOSE 8443

USER tomcat

ENTRYPOINT ["/entrypoint.sh"]
