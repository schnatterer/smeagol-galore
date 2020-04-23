# Define image versions for all stages
FROM maven:3.6.3-jdk-11-slim as maven
FROM bitnami/tomcat:9.0.34-debian-10-r8 as tomcat

# Define global values in a central, DRY way
FROM tomcat as builder
ENV SMEAGOL_VERSION=v0.5.6
ENV SCM_SCRIPT_PLUGIN_VERSION=2.0.0-rc2
ENV SCM_CAS_PLUGIN_VERSION=2.0.0-rc5
ENV SCM_VERSION=2.0.0-rc7
ENV CATALINA_HOME=/dist/opt/bitnami/tomcat/webapps/

USER root
RUN mkdir -p ${CATALINA_HOME}
RUN apt-get update
RUN apt-get install -y wget zip dumb-init


FROM maven as cas-mavencache
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn
ADD cas/pom.xml /cas/pom.xml
WORKDIR /cas
RUN mvn dependency:resolve dependency:resolve-plugins


FROM maven as cas-mavenbuild
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn 
COPY --from=cas-mavencache /mvn/ /mvn/
ADD cas/ /cas/
WORKDIR /cas
RUN mvn compile war:exploded


# User separate downloader stages for better caching (especially downloads)
FROM builder as scm-downloader

ENV SCM_PKG_URL=https://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm/scm-server/${SCM_VERSION}/scm-server-${SCM_VERSION}-app.tar.gz
ENV SCM_REQUIRED_PLUGINS=/dist/opt/scm-server/required-plugins

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
# config
COPY scm/resources /dist


FROM builder as smeagol-downloader
# Smeagol lacks JAXB (required from Java > 8). Use a custom build for now
#RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war
RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/schnatterer/smeagol/${SMEAGOL_VERSION}-jaxb/smeagol-${SMEAGOL_VERSION}-jaxb.war

# Set plantuml.com as plantuml renderer. Alternative would be to deploy plantuml
# "Fix" executable war (which seems to confuse jar & zip utilities)
ARG PLANTUMLSERVER="http://www.plantuml.com/plantuml/png/"
RUN set -x && \
  zip -F /tmp/smeagol-exec.war --out /tmp/smeagol.war && \
  unzip /tmp/smeagol.war -d ${CATALINA_HOME}/smeagol && \
  sed -i "s#rendererURL:\"/plantuml/png/#rendererURL:\"${PLANTUMLSERVER}#g" "$(ls ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/static/js/main*.js)"
# Config
COPY smeagol/application.yml /dist/application.yml
COPY smeagol/logback.xml ${CATALINA_HOME}/smeagol/WEB-INF/classes/logback.xml


FROM builder as aggregator
# CAS
COPY --from=cas-mavenbuild /cas/target/cas ${CATALINA_HOME}/cas
# config
COPY cas/etc/ /dist/etc/

COPY --from=scm-downloader /dist /dist
COPY --from=smeagol-downloader /dist /dist

# Tomcat Config (TLS & root URL redirect)
COPY tomcat /dist/opt/bitnami/tomcat/
COPY entrypoint.sh /dist/opt/bitnami/scripts/tomcat/

# Needed when running with read-only file system and mounting this folder as volume (which leads to being owend by 0:0)
RUN mkdir /dist/opt/bitnami/tomcat/temp
# Allow for editing cacerts in entrypoint.sh
RUN mkdir -p /dist/opt/bitnami/java/lib/security/ && \
    cp /opt/bitnami/java/lib/security/cacerts /dist/opt/bitnami/java/lib/security/
# Create room for certs
RUN mkdir -p /dist/config/certs
# Make home folder writable
RUN mkdir -p /dist/home/tomcat/.scm
# Once copied to the final stage everythings seems to be owend by root:root.
# That is, the owner seems not to be preseverd, even when chown to UID 1001 here.
# At least on Docker Hub this still pehttps://github.com/moby/moby/pull/38599oby/moby/pull/38599
# Good thing: Bitnami images are always run with root group
# See https://docs.openshift.com/container-platform/4.3/openshift_images/create-images.html#images-create-guide-openshift_create-images
# So we need to make sure to chmod everything we need at run time to the group not only the user.
# That's why we use 770 instead of 700.
RUN chmod -R 770 /dist
    
# Create Tomcat User so SCMM has a HOME to write to
RUN useradd --uid 1001 --gid 0 --shell /bin/bash --create-home tomcat && \
    cp /etc/passwd /dist/etc

# Use init system, so we still have proper signal handling even though restart loop in entrypoint.sh required by SCMM
RUN mkdir -p /dist/usr/bin/ && \
    cp /usr/bin/dumb-init /dist/usr/bin/dumb-init

# Use authbind to allow tomcat user to bin to port 443
# Unfortunately, COPYing capabilities does not work in classic docker build
# https://github.com/moby/moby/issues/20435 
#RUN setcap CAP_NET_BIND_SERVICE=+ep /opt/bitnami/java/bin/java # requires libcap2-bin
# Another option could be to install libcap and create a "capability.conf" with
# cap_net_bind_service		tomcat
RUN cd /tmp && apt-get download authbind
RUN dpkg-deb -X /tmp/*.deb /dist
RUN touch /dist/etc/authbind/byport/443 /dist/etc/authbind/byport/80 && \
    chown 1001:0 /dist/etc/authbind/byport/* && \
    chmod 550 /dist/etc/authbind/byport/*

FROM tomcat
# Don't --chown=1001:0  here, or some binaries/libraries won't work (libcap/authbind)
COPY --from=aggregator /dist /
VOLUME /home/tomcat/.scm
EXPOSE 8443 2222
ENTRYPOINT [ "/usr/bin/dumb-init", "--", "/opt/bitnami/scripts/tomcat/entrypoint.sh" ]
# Remove base image's CMD - here it is used to pass additional CATALINA_ARGS conveniently
CMD []
