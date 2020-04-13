# Define image versions for all stages
FROM maven:3.6.1-jdk-8-alpine as maven
FROM bitnami/tomcat:9.0.34-debian-10-r3 as tomcat

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
ENV CATALINA_HOME=/dist/opt/bitnami/tomcat/webapps/
ENV SCM_SCRIPT_PLUGIN_VERSION=2.0.0-rc1
ENV SCM_CAS_PLUGIN_VERSION=2.0.0-rc2
ENV SCM_VERSION=2.0.0-rc5
ENV SCM_PKG_URL=https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm/scm-server/${SCM_VERSION}/scm-server-${SCM_VERSION}-app.tar.gz
ENV SCM_REQUIRED_PLUGINS=/dist/opt/scm-server/required-plugins

COPY --from=mavenbuild /cas/target/cas.war /tmp/cas.war

RUN set -x
RUN apk add --no-cache --update zip unzip curl unzip
RUN mkdir -p ${CATALINA_HOME}
# Smeagol lacks JAXB (required from Java > 8). Use a custom build for now
#RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war
RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/schnatterer/smeagol/${SMEAGOL_VERSION}-jaxb/smeagol-${SMEAGOL_VERSION}-jaxb.war
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
COPY tomcat /dist/opt/bitnami/tomcat/
# Smeagol config
COPY smeagol/application.yml /dist/application.yml
COPY smeagol/logback.xml ${CATALINA_HOME}/smeagol/WEB-INF/classes/logback.xml
COPY entrypoint.sh /dist/opt/bitnami/scripts/tomcat/
# Allow for editing cacerts in entrypoint.sh
# Note on chown 1001:0
# Bitnami images are always run with root group
# See https://docs.openshift.com/container-platform/4.3/openshift_images/create-images.html#images-create-guide-openshift_create-images
COPY --from=tomcat --chown=1001:0  /opt/bitnami/java/lib/security/cacerts /dist/opt/bitnami/java/lib/security/cacerts
RUN \
      chown -R 1001:0 /dist/opt/bitnami/java/lib/security/cacerts && \
      # Needed when running with read-only file  system and mounting this folder as volume (which leads to being owend by 0:0)
      mkdir /dist/opt/bitnami/tomcat/temp && \
      chmod 770 /dist/opt/bitnami/tomcat/temp && \
      chmod 770 /dist/opt/bitnami/java/lib/security/cacerts
# Make volume writable
RUN \
  mkdir -p /dist/home/tomcat/.scm  && \
  chown -R 1001:0 /dist/home/tomcat && \
  chown -R 1001:0 /dist/home/tomcat/.scm  && \
  chown -R 1001:0 /dist/etc/cas && \
  chmod -R 770 /dist/home/tomcat

# Create room for certs
RUN mkdir -p /dist/config/certs

FROM tomcat as dist
USER root

# For now tomcat native libs must be built manually: https://github.com/bitnami/bitnami-docker-tomcat/issues/76#issuecomment-499885520
# Install the required dependencies to build tomcat-native
RUN install_packages libapr1-dev libssl-dev openjdk-11-jdk-headless gcc make
# Build tomcat-native
RUN tar -xzvf /opt/bitnami/tomcat/bin/tomcat-native.tar.gz -C /tmp
RUN cd /tmp/tomcat-native-*/native && \
    ./configure --with-java-home=/usr/lib/jvm/java-11-openjdk-amd64 && \
    make && \
    cd .libs && \
    rm -f libtcnative-1.a libtcnative-1.la libtcnative-1.lai
RUN mkdir -p /dist/usr/lib && \
    cp /tmp/tomcat-native-*/native/.libs/* /dist/usr/lib

# Aggregate folder from other stages
COPY --from=downloader /dist /dist

# Create Tomcat User so SCMM has a HOME to write to
RUN useradd --uid 1001 --gid 0 --shell /bin/bash --create-home tomcat && \
    cp /etc/passwd /dist/etc

FROM tomcat
COPY --from=dist --chown=1001:0  /dist /
VOLUME /home/tomcat/.scm
EXPOSE 8443 2222
# Remove base images CMD - here it is used to pass additional CATALINA_ARGS conveniently
CMD []
