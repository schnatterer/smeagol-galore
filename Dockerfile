# Define image versions for all stages
FROM adoptopenjdk/openjdk11:jre-11.0.13_8-debianslim as jre
FROM maven:3.8.4-jdk-11-slim as maven
FROM schnatterer/letsencrypt-tomcat:0.4.0 as letsencrypt-tomcat

# Define global values in a central, DRY way
FROM jre as builder

# Note: On update patching the link to SCM-Manager into Smeagol UI has to be adapted :/
ENV SMEAGOL_VERSION=v1.6.1-1
# https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war.md5
ENV SMEAGOL_MD5=78b9fec96ad15e841a32675995ef9421

# https://packages.scm-manager.org/service/rest/repository/browse/plugin-releases/sonia/scm/plugins/
ENV SCM_SCRIPT_PLUGIN_VERSION=2.3.2
# e.g. https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-script-plugin/2.3.0/scm-script-plugin-2.3.0.smp.sha256
ENV SCM_SCRIPT_PLUGIN_SHA256=4e52dc010b0682c9321f22573f698a59f0b667e3ef2a3a6885ffa57feeebfb5e 
ENV SCM_CODE_EDITOR_PLUGIN_VERSION=1.0.0
ENV SCM_CODE_EDITOR_PLUGIN_SHA256=c5d80fa7ab9723fd3d41b8422ec83433bc3376f59850d97a589fe093f5ca8989
ENV SCM_CAS_PLUGIN_VERSION=2.4.0
ENV SCM_CAS_PLUGIN_SHA256=bd9a0e0794fb1be40f357cbbde7396889055bd1af2c42b4f2cdb34763c5fb372
ENV SCM_SMEAGOL_PLUGIN_VERSION=1.2.1
ENV SCM_SMEAGOL_PLUGIN_SHA256=d588537fc77ddb85adaaecf43a94a3e0cf32880ec4d3b0aadf9d7c0fc50d344d
ENV SCM_REST_LEGACY_PLUGIN_VERSION=2.0.0
ENV SCM_REST_LEGACY_PLUGIN_MD5=1d7943bc76b0e88a79770f3285c3f272
ENV SCM_VERSION=2.28.0
# https://packages.scm-manager.org/repository/releases/sonia/scm/packaging/unix/${SCM_VERSION}/unix-${SCM_VERSION}.tar.gz.sha256
ENV SCM_SHA256=c4108d671304e916003391ac81f74f04c699e5c24587539c86107c9b813ed1f6

ENV CATALINA_HOME=/dist/tomcat/webapps/

USER root
RUN mkdir -p ${CATALINA_HOME}
RUN apt-get update
RUN apt-get install -y wget zip gpg


FROM maven as cas-mavencache
ENV MAVEN_OPTS='-Dmaven.repo.local=/mvn'
ADD cas/pom.xml /cas/pom.xml
WORKDIR /cas
# Using go-offline results in issues resolving xmldsig from http://developer.ja-sig.org/maven2/ :-/
RUN mvn dependency:resolve dependency:resolve-plugins


FROM maven as cas-mavenbuild
ENV MAVEN_OPTS='-Dmaven.repo.local=/mvn' 
COPY --from=cas-mavencache /mvn/ /mvn/
ADD cas/ /cas/
WORKDIR /cas
RUN mvn compile war:exploded



FROM maven as tomcat-mavencache
ENV MAVEN_OPTS='-Dmaven.repo.local=/mvn'
ADD tomcat/pom.xml /tomcat/pom.xml
WORKDIR /tomcat
RUN mvn dependency:go-offline

FROM maven as tomcat-mavenbuild
ENV MAVEN_OPTS='-Dmaven.repo.local=/mvn'
COPY --from=tomcat-mavencache /mvn/ /mvn/
ADD tomcat/ /tomcat/
WORKDIR /tomcat
RUN mvn package


# User separate downloader stages for better caching (especially downloads)
FROM builder as scm-downloader

ENV SCM_PKG_URL=https://packages.scm-manager.org/repository/releases/sonia/scm/packaging/unix/${SCM_VERSION}/unix-${SCM_VERSION}.tar.gz
ENV SCM_REQUIRED_PLUGINS=/dist/opt/scm-server/required-plugins

RUN curl --fail -Lks ${SCM_PKG_URL} -o /tmp/scm-server.tar.gz \
    && echo "${SCM_SHA256} */tmp/scm-server.tar.gz" | sha256sum -c -
RUN curl --fail -Lks ${SCM_PKG_URL}.asc -o /tmp/scm-server.tar.gz.asc
RUN gpg --receive-keys 8A44E41377D51FA4
RUN gpg --batch --verify /tmp/scm-server.tar.gz.asc /tmp/scm-server.tar.gz
RUN gunzip /tmp/scm-server.tar.gz
RUN tar -C /opt -xf /tmp/scm-server.tar
RUN unzip -o /opt/scm-server/var/webapp/scm-webapp.war -d ${CATALINA_HOME}/scm
# download essential SCMM plugins
RUN mkdir -p ${SCM_REQUIRED_PLUGINS}
# Plugins are not signed, so no verification possible here
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-rest-legacy-plugin/${SCM_REST_LEGACY_PLUGIN_VERSION}/scm-rest-legacy-plugin-${SCM_REST_LEGACY_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-rest-legacy-plugin.smp \
  && echo "${SCM_REST_LEGACY_PLUGIN_MD5} *${SCM_REQUIRED_PLUGINS}/scm-rest-legacy-plugin.smp" | md5sum -c - 
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-code-editor-plugin/${SCM_CODE_EDITOR_PLUGIN_VERSION}/scm-code-editor-plugin-${SCM_CODE_EDITOR_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-code-editor-plugin.smp \
  && echo "${SCM_CODE_EDITOR_PLUGIN_SHA256} *${SCM_REQUIRED_PLUGINS}/scm-code-editor-plugin.smp" | sha256sum -c - 
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-script-plugin/${SCM_SCRIPT_PLUGIN_VERSION}/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-script-plugin.smp \
  && echo "${SCM_SCRIPT_PLUGIN_SHA256} *${SCM_REQUIRED_PLUGINS}/scm-script-plugin.smp" | sha256sum -c - 
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION}/scm-cas-plugin-${SCM_CAS_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-cas-plugin.smp \
  && echo "${SCM_CAS_PLUGIN_SHA256} *${SCM_REQUIRED_PLUGINS}/scm-cas-plugin.smp" | sha256sum -c - 
RUN curl --fail -Lks https://packages.scm-manager.org/repository/plugin-releases/sonia/scm/plugins/scm-smeagol-plugin/${SCM_SMEAGOL_PLUGIN_VERSION}/scm-smeagol-plugin-${SCM_SMEAGOL_PLUGIN_VERSION}.smp -o ${SCM_REQUIRED_PLUGINS}/scm-smeagol-plugin.smp \
  && echo "${SCM_SMEAGOL_PLUGIN_SHA256} *${SCM_REQUIRED_PLUGINS}/scm-smeagol-plugin.smp" | sha256sum -c - 

# Make logging less verbose
COPY /scm/logback.xml ${CATALINA_HOME}/scm/WEB-INF/classes/logback.xml
# config
COPY scm/resources /dist


FROM builder as smeagol-downloader
RUN wget -O /tmp/smeagol-exec.war https://jitpack.io/com/github/cloudogu/smeagol/${SMEAGOL_VERSION}/smeagol-${SMEAGOL_VERSION}.war \
  && echo "${SMEAGOL_MD5} */tmp/smeagol-exec.war" | md5sum -c - 

# Set plantuml.com as plantuml renderer. Alternative would be to deploy plantuml
# "Fix" executable war (which seems to confuse jar & zip utilities)
ENV PLANTUMLSERVER="https://www.plantuml.com/plantuml/png/"
RUN set -x && \
  zip -F /tmp/smeagol-exec.war --out /tmp/smeagol.war && \
  unzip /tmp/smeagol.war -d ${CATALINA_HOME}/smeagol
RUN sed -i "s#rendererURL:\"/plantuml/png/#rendererURL:\"${PLANTUMLSERVER}#g" "$(ls ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/static/js/main*.js)"  
# Patch link to SCM-Manager into Smeagol UI
RUN sed -i 's#\(navbar-right"},e\)#\1,E.a.createElement("li",null, E.a.createElement("a",{href:"/scm"},"SCM-Manager"))#g' "$(ls ${CATALINA_HOME}/smeagol/WEB-INF/classes/static/static/js/main*.js)"
  
# Config
COPY smeagol/application.yml /dist/application.yml
COPY smeagol/logback.xml ${CATALINA_HOME}/smeagol/WEB-INF/classes/logback.xml


FROM builder as aggregator
# CAS
COPY --from=cas-mavenbuild /cas/target/cas ${CATALINA_HOME}/cas
# Mitigate any possible attack vectors similar to Log4Shell (CVE-2021-44228)
# https://www.slf4j.org/log4shell.html
RUN cd ${CATALINA_HOME}/cas/WEB-INF/lib/ && zip -q -d log4j-*.jar org/apache/log4j/net/JMSAppender.class
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