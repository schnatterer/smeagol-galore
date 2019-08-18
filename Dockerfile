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
ENV SCM_SCRIPT_PLUGIN_VERSION=2.0.0-SNAPSHOT
# No stable version available just yet
#ENV SCM_VERSION=

COPY --from=mavenbuild /cas/target/cas.war /tmp/cas.war

RUN set -x
RUN apk add --no-cache --update zip unzip curl unzip
RUN mkdir -p ${CATALINA_HOME}
RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war
RUN unzip /tmp/cas.war -d ${CATALINA_HOME}/cas

# Install scm
COPY /scm/utils /opt/utils
RUN curl -Lks https://oss.cloudogu.com/jenkins/job/scm-manager/job/scm-manager-2.x/job/2.0.0-m3/lastSuccessfulBuild/artifact/scm-server/target/scm-server-app.tar.gz -o /tmp/scm-server.tar.gz
RUN gunzip /tmp/scm-server.tar.gz
RUN tar -C /opt -xf /tmp/scm-server.tar
RUN unzip /opt/scm-server/var/webapp/scm-webapp.war -d ${CATALINA_HOME}/scm
# install scm-script-plugin
RUN curl -Lks https://oss.cloudogu.com/jenkins/job/scm-manager/job/scm-manager-bitbucket/job/scm-script-plugin/job/2.0.0/lastSuccessfulBuild/artifact/target/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.smp -o ${CATALINA_HOME}/scm/WEB-INF/plugins/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.smp
RUN java -cp /opt/utils AddPluginToIndex ${CATALINA_HOME}/scm/WEB-INF/plugins/plugin-index.xml ${CATALINA_HOME}/scm/WEB-INF/plugins/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.smp
# Make logging less verbose
COPY /scm/logging.xml ${CATALINA_HOME}/scm/WEB-INF/classes/logback.xml

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
COPY entrypoint.sh /dist


# Build final image
# Before switching to tomcat 9 make sure there is a solution for the permission proble with aufs:
# https://github.com/docker-library/tomcat/issues/35
# Maybe update to "tomcat:8.5" first?
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

EXPOSE 8080 2222

USER tomcat

ENTRYPOINT ["/entrypoint.sh"]