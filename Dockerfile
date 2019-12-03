# Define maven version for all stages
FROM maven:3.6.1-jdk-8-alpine as maven

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
RUN mvn package

# Download and cache webapps - we need java for scm, so just use another maven container here
FROM maven as downloader
ENV SMEAGOL_VERSION=v0.5.6
ENV CATALINA_HOME=/dist/usr/local/tomcat/webapps
ENV SCM_SCRIPT_PLUGIN_VERSION=2.0.0-rc1
ENV SCM_CAS_PLUGIN_VERSION=2.0.0-rc1
ENV SCM_VERSION=2.0.0-rc1
ENV SCM_PKG_URL=https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm/scm-server/${SCM_VERSION}/scm-server-${SCM_VERSION}-app.tar.gz
ENV SCM_REQUIRED_PLUGINS=/dist/opt/scm-server/required-plugins

COPY --from=mavenbuild /cas/target/cas.war /tmp/cas.war

RUN set -x
RUN apk add --no-cache --update zip unzip curl unzip
RUN mkdir -p ${CATALINA_HOME}
RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war
RUN unzip /tmp/cas.war -d ${CATALINA_HOME}/cas

# Install scm
RUN curl --fail -Lks ${SCM_PKG_URL} -o /tmp/scm-server.tar.gz
RUN gunzip /tmp/scm-server.tar.gz
RUN tar -C /opt -xf /tmp/scm-server.tar
RUN unzip /opt/scm-server/var/webapp/scm-webapp.war -d ${CATALINA_HOME}/scm
# download scm-script-plugin & scm-cas-plugin
RUN mkdir -p ${SCM_REQUIRED_PLUGINS}
RUN curl --fail -Lks https://maven.scm-manager.org/nexus/content/repositories/plugin-releases/sonia/scm/plugins/scm-script-plugin/${SCM_SCRIPT_PLUGIN_VERSION}/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-script-plugin.smp
RUN curl --fail -Lks https://maven.scm-manager.org/nexus/content/repositories/plugin-releases/sonia/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION}/scm-cas-plugin-${SCM_CAS_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-cas-plugin.smp
# Make logging less verbose
COPY /scm/logback.xml ${CATALINA_HOME}/scm/WEB-INF/classes/logback.xml

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
COPY scm/resources /dist
# Tomcat Config (TLS & root URL redirect)
COPY tomcat /dist/usr/local/tomcat
# Smeagol config
COPY smeagol/application.yml /dist/usr/local/tomcat/application.yml
COPY smeagol/logback.xml ${CATALINA_HOME}/smeagol/WEB-INF/classes/logback.xml
COPY entrypoint.sh /dist


# Build final image
# Before switching to tomcat 9 make sure there is a solution for the permission proble with aufs:
# https://github.com/docker-library/tomcat/issues/35
# 8.5.41 seems to be the last "alpine" variat of tomcat 8.5. As of 2019/11 there's 8.5.47
# Switch to "slim"?
# #https://github.com/Unidata/tomcat-docker/blob/master/Dockerfile
FROM tomcat:8.5.41-jre8-alpine
ARG USER_ID="1000"
ARG GROUP_ID="1000"

COPY --from=downloader /dist /

RUN \
  apk update && \
  apk upgrade && \
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
  # Needed when running with read-only file system and mounting this folder as volume (which leads to being owend by 0:0)
  chmod 777 /usr/local/tomcat/temp && \
  chmod 774 /etc/ssl/certs/java/cacerts && \
  chmod -R 770 /home/tomcat && \
  chmod 400 ${CATALINA_HOME}/conf/*

VOLUME /home/tomcat/.scm

EXPOSE 8443 2222

USER tomcat

ENTRYPOINT ["/entrypoint.sh"]