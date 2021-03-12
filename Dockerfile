# Define image versions for all stages
FROM adoptopenjdk/openjdk11:jre-11.0.10_9-debianslim as jre
FROM maven:3.6.3-jdk-11-slim as maven
FROM schnatterer/letsencrypt-tomcat:0.4.0 as letsencrypt-tomcat

# Define global values in a central, DRY way
FROM jre as builder
ENV SMEAGOL_VERSION=v0.7.0-1 
ENV SCM_SCRIPT_PLUGIN_VERSION=2.2.0
ENV SCM_CODE_EDITOR_PLUGIN_VERSION=1.0.0
ENV SCM_CAS_PLUGIN_VERSION=2.2.3
ENV SCM_SMEAGOL_PLUGIN_VERSION=1.0.0
ENV SCM_REST_LEGACY_PLUGIN_VERSION=2.0.0
ENV SCM_VERSION=2.14.1
ENV CATALINA_HOME=/dist/tomcat/webapps/

USER root
RUN mkdir -p ${CATALINA_HOME}
RUN apt-get update
RUN apt-get install -y wget zip gpg


FROM maven as cas-mavencache
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn
ADD cas/pom.xml /cas/pom.xml
WORKDIR /cas
# Using go-offline results in issues resolving xmldsig from http://developer.ja-sig.org/maven2/ :-/
RUN mvn dependency:resolve dependency:resolve-plugins


FROM maven as cas-mavenbuild
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn 
COPY --from=cas-mavencache /mvn/ /mvn/
ADD cas/ /cas/
WORKDIR /cas
RUN mvn compile war:exploded


FROM maven as tomcat-mavencache
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn
ADD tomcat/pom.xml /tomcat/pom.xml
WORKDIR /tomcat
RUN mvn dependency:go-offline

FROM maven as tomcat-mavenbuild
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn 
COPY --from=tomcat-mavencache /mvn/ /mvn/
ADD tomcat/ /tomcat/
WORKDIR /tomcat
RUN mvn package


# User separate downloader stages for better caching (especially downloads)
FROM builder as scm-downloader

ENV SCM_PKG_URL=https://packages.scm-manager.org/repository/releases/sonia/scm/packaging/unix/${SCM_VERSION}/unix-${SCM_VERSION}.tar.gz
ENV SCM_REQUIRED_PLUGINS=/dist/opt/scm-server/required-plugins

RUN curl --fail -Lks ${SCM_PKG_URL} -o /tmp/scm-server.tar.gz
RUN curl --fail -Lks ${SCM_PKG_URL}.asc -o /tmp/scm-server.tar.gz.asc
RUN gpg --receive-keys 8A44E41377D51FA4
RUN gpg --batch --verify /tmp/scm-server.tar.gz.asc /tmp/scm-server.tar.gz
RUN gunzip /tmp/scm-server.tar.gz
RUN tar -C /opt -xf /tmp/scm-server.tar
RUN unzip -o /opt/scm-server/var/webapp/scm-webapp.war -d ${CATALINA_HOME}/scm
# download essential SCMM plugins
RUN mkdir -p ${SCM_REQUIRED_PLUGINS}
# Plugins are not signed, so no verification possible here
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-rest-legacy-plugin/${SCM_REST_LEGACY_PLUGIN_VERSION}/scm-rest-legacy-plugin-${SCM_REST_LEGACY_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-rest-legacy-plugin.smp
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-code-editor-plugin/${SCM_CODE_EDITOR_PLUGIN_VERSION}/scm-code-editor-plugin-${SCM_CODE_EDITOR_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-code-editor-plugin.smp
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-script-plugin/${SCM_SCRIPT_PLUGIN_VERSION}/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-script-plugin.smp
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION}/scm-cas-plugin-${SCM_CAS_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-cas-plugin.smp
#RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-smeagol-plugin/${SCM_SMEAGOL_PLUGIN_VERSION}/scm-smeagol-plugin-${SCM_SMEAGOL_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-smeagol-plugin.smp
RUN curl --fail -Lks https://oss.cloudogu.com/jenkins/job/scm-manager-plugins/job/scm-smeagol-plugin/job/develop/lastSuccessfulBuild/artifact/build/libs/scm-smeagol-plugin.smp -o ${SCM_REQUIRED_PLUGINS}/scm-smeagol-plugin.smp

# Make logging less verbose
COPY /scm/logback.xml ${CATALINA_HOME}/scm/WEB-INF/classes/logback.xml
# config
COPY scm/resources /dist


FROM builder as smeagol-downloader
RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war

# Set plantuml.com as plantuml renderer. Alternative would be to deploy plantuml
# "Fix" executable war (which seems to confuse jar & zip utilities)
ENV PLANTUMLSERVER="http://www.plantuml.com/plantuml/png/"
RUN set -x && \
  zip -F /tmp/smeagol-exec.war --out /tmp/smeagol.war && \
  unzip /tmp/smeagol.war -d ${CATALINA_HOME}/smeagol && \
  sed -i "s#rendererURL:\"/plantuml/png/#rendererURL:\"${PLANTUMLSERVER}#g" "$(ls ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/static/js/main*.js)" && \ 
  # Patch link to SCM-Manager into Smeagol UI
  sed -i 's#\(navbar-right"},e\)#\1,_.a.createElement("li",null,_.a.createElement("a",{href:"/scm"},"SCM-Manager"))#g' "$(ls ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/static/js/main*.js)"
  
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

# Use smeagol favicons also for cas
RUN cp ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/favicon* ${CATALINA_HOME}/cas

# Root webapp
COPY tomcat/webapps /dist/tomcat/webapps

COPY entrypoint.sh /dist/

# Needed when running with read-only file system and mounting this folder as volume (which leads to being owend by 0:0)
RUN mkdir /dist/tomcat/work
# Allow for editing cacerts in entrypoint.sh
RUN mkdir -p /dist/opt/java/openjdk/lib/security/ && \
    cp /opt/java/openjdk/lib/security/cacerts /dist/opt/java/openjdk/lib/security/cacerts
# Create room for certs
RUN mkdir -p /dist/config/certs
# Make home folder writable
RUN mkdir -p /dist/home/tomcat/.scm
RUN mkdir -p /dist/home/tomcat/.smeagol
# Once copied to the final stage everythings seems to be owend by root:root.
# That is, the owner seems not to be preseverd, even when chown to UID 1001 here.
# At least on Docker Hub this still pehttps://github.com/moby/moby/pull/38599oby/moby/pull/38599
# To make things easier the final image will run as root group. For more info on this "pattern", see https://docs.openshift.com/container-platform/4.3/openshift_images/create-images.html#images-create-guide-openshift_create-images
# So we need to make sure to chmod everything we need at run time to the group not only the user.
# That's why we use 770 instead of 700.
RUN chmod -R 770 /dist
    
# Create Tomcat User so SCMM has a HOME to write to
RUN useradd --uid 1001 --gid 0 --shell /bin/bash --create-home tomcat && \
    cp /etc/passwd /dist/etc

# Use authbind to allow tomcat user to bin to port 443
# Unfortunately, COPYing capabilities does not work in classic docker build
# https://github.com/moby/moby/issues/20435 
#RUN setcap CAP_NET_BIND_SERVICE=+ep /opt/java/openjdk/bin/java # requires libcap2-bin
# Another option could be to install libcap and create a "capability.conf" with
# cap_net_bind_service		tomcat
RUN cd /tmp && apt-get download authbind
RUN dpkg-deb -X /tmp/*.deb /dist
RUN touch /dist/etc/authbind/byport/443 /dist/etc/authbind/byport/80 && \
    chown 1001:0 /dist/etc/authbind/byport/* && \
    chmod 550 /dist/etc/authbind/byport/*

# Copy letsencrypt-related stuff
COPY --from=letsencrypt-tomcat /letsencrypt /dist

# Serve /static
# It would be simpler to link ROOT -> static but it seems that tomcat does not follow symlinks when serving static content
# So just do it the other way round
RUN mkdir -p /dist/tomcat/webapps/ROOT/.well-known/acme-challenge
RUN rm -rf /dist/static/.well-known/acme-challenge
RUN ln -s /tomcat/webapps/ROOT/.well-known/acme-challenge /dist/static/.well-known/acme-challenge
RUN chmod 770 /dist/tomcat/webapps/ROOT/.well-known/acme-challenge

# As SG's setup is rather complex the essential code of meta-entrypoint was included (and altered) in entrypoint.sh 
RUN rm /dist/meta-entrypoint.sh

# Copy APR lib
COPY --from=letsencrypt-tomcat /lib /dist/

# Copy embedded tomcat
COPY --from=tomcat-mavenbuild /tomcat/target/tomcat-jar-with-dependencies.jar /dist/app/app.jar


FROM jre
# Don't --chown=1001:0  here, or some binaries/libraries won't work (libcap/authbind)
COPY --from=aggregator /dist /

VOLUME /home/tomcat/.scm
VOLUME /home/tomcat/.smeagol
EXPOSE 8443 2222
USER 1001:0
ENTRYPOINT [ "/entrypoint.sh" ]