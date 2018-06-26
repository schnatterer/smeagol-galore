# Define maven version for all stages
FROM maven:3.5.3-jdk-8-alpine as maven


FROM maven as mavencache
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn

ADD cas/pom.xml /cas/pom.xml

WORKDIR /cas
RUN mvn dependency:resolve dependency:resolve-plugins


FROM maven as mavenbuild

ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn  \
    #SCM_CAS_PLUGIN_VERSION=1.7  \
    SCM_SCRIPT_PLUGIN_VERSION=1.6 \
    GROOVY_VERSION=2.4.12

COPY --from=mavencache /mvn/ /mvn/

#RUN set -x && \
  # Get scm-cas-plugin and all its dependencies
  #mkdir -p /scm-runtime-plugins/de/triology/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION} && \
  #wget -O /scm-runtime-plugins/de/triology/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION}/scm-cas-plugin-${SCM_CAS_PLUGIN_VERSION}.jar https://maven.scm-manager.org/nexus/service/local/repositories/releases/content/de/triology/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION}/scm-cas-plugin-${SCM_CAS_PLUGIN_VERSION}.jar && \
  #wget -O /tmp/scm-cas-plugin-pom.xml https://maven.scm-manager.org/nexus/service/local/repositories/releases/content/de/triology/scm/plugins/scm-cas-plugin/${SCM_CAS_PLUGIN_VERSION}/scm-cas-plugin-${SCM_CAS_PLUGIN_VERSION}.pom && \
  #mvn -f /tmp/scm-cas-plugin-pom.xml dependency:copy-dependencies -DoutputDirectory=/scm-core-plugins -DincludeScope=runtime
  # Is later copied straight to .scm in entrypoint, because copying to lib causes jersey juice "Missing dependency for method ..." errors
  #mvn -f /tmp/scm-cas-plugin-pom.xml dependency:copy-dependencies -Dmdep.useRepositoryLayout -DoutputDirectory=/scm-runtime-plugins -DincludeScope=runtime

RUN set -x && \
  mkdir /scm-core-plugins && \
  curl -Lks http://repo1.maven.org/maven2/org/codehaus/groovy/groovy-all/${GROOVY_VERSION}/groovy-all-${GROOVY_VERSION}.jar -o /scm-core-plugins/groovy-all-${GROOVY_VERSION}.jar && \
  curl -Lks http://maven.scm-manager.org/nexus/content/repositories/releases/sonia/scm/plugins/scm-script-plugin/${SCM_SCRIPT_PLUGIN_VERSION}/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.jar -o /scm-core-plugins/scm-script-plugin-${SCM_SCRIPT_PLUGIN_VERSION}.jar

# TODO Build cas
#ADD cas/ /cas/
#RUN set -x && \
#  cd /cas && mvn package


# Download and cache webapps
FROM alpine:3.7 as downloader
ENV SCM_VERSION=1.54

# TODO Use official war (versiom > 0.5.1) here!
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

# "Install" scm plugins
COPY --from=mavenbuild /scm-core-plugins /webapps/scm/WEB-INF/lib

#COPY --from=mavenbuild /cas/target/cas.war /webapps/cas.war
COPY cas/target/cas.war /webapps/cas.war


FROM tomcat:9.0.8-jre8-alpine

RUN \
  apk add --no-cache --update su-exec && \
  mkdir /home/tomcat
  # TODO add umask 007 or 077?
  #umask "077"

# TODO delete tomcat default webapps
# TODO consolidate/optimize COPY stages

COPY --from=downloader /webapps/ /usr/local/tomcat/webapps/

# Plugins installed at runtime
#COPY --from=mavenbuild /scm-runtime-plugins/ /scm-runtime-plugins

COPY scm /
# Tomcat Config (TLS & root URL redirect)
COPY tomcat /usr/local/tomcat
# Smeagol config
COPY smeagol/application.yml /usr/local/tomcat/application.yml
COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]