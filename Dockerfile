FROM centos:centos7 as temp

ENV jetty_version=9.4.29.v20200521 \
    jetty_hash=71b572d99fe2c1342231ac3bd2e14327f523e532dd01ff203f331d52f2cf2747 \
    idp_version=4.0.1 \
    idp_hash=832f73568c5b74a616332258fd9dc555bb20d7dd9056c18dc0ccf52e9292102a

ENV JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/shib-jetty-base \
    PATH=$PATH:$JRE_HOME/bin

RUN yum -y update \
    && yum -y install wget tar which unzip \
    && yum -y clean all

# Install Amazon Corretto Java 11
RUN rpm --import https://yum.corretto.aws/corretto.key \
    && curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo \
    && yum install -y java-11-amazon-corretto-devel

# Download Jetty, verify the hash, and install, initialize a new base
RUN wget -q https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/$jetty_version/jetty-distribution-$jetty_version.tar.gz \
    && echo "$jetty_hash  jetty-distribution-$jetty_version.tar.gz" | sha256sum -c - \
    && tar -zxvf jetty-distribution-$jetty_version.tar.gz -C /opt \
    && ln -s /opt/jetty-distribution-$jetty_version/ /opt/jetty-home

# Config Jetty
RUN mkdir -p /opt/shib-jetty-base/modules /opt/shib-jetty-base/lib/ext  /opt/shib-jetty-base/lib/logging /opt/shib-jetty-base/resources \
    && cd /opt/shib-jetty-base \
    && touch start.ini \
    && java -jar ../jetty-home/start.jar --add-to-start=http,deploy,ext,annotations,jstl,rewrite

# Download Shibboleth IdP, verify the hash, and install
RUN wget -q https://shibboleth.net/downloads/identity-provider/$idp_version/shibboleth-identity-provider-$idp_version.tar.gz \
    && echo "$idp_hash  shibboleth-identity-provider-$idp_version.tar.gz" | sha256sum -c - \
    && tar -zxvf  shibboleth-identity-provider-$idp_version.tar.gz -C /opt \
    && ln -s /opt/shibboleth-identity-provider-$idp_version/ /opt/shibboleth-idp

# Setting owner ownership and permissions on new items in this command
RUN useradd jetty -U -s /bin/false \
    && chown -R root:jetty /opt \
    && chmod -R 640 /opt

COPY opt/shib-jetty-base/ /opt/shib-jetty-base/
COPY opt/shibboleth-idp/ /opt/shibboleth-idp/

# Setting owner ownership and permissions on new items from the COPY command
RUN mkdir /opt/shib-jetty-base/logs \
    && chown -R root:jetty /opt/shib-jetty-base \
    && chmod -R 640 /opt/shib-jetty-base \
    && chmod -R 750 /opt/shibboleth-idp/bin
    
FROM centos:centos7

LABEL maintainer="Gary Windham"\
      idp.java.version="11.0.7" \
      idp.jetty.version="9.4.29.20200521" \
      idp.version="4.0.1"

ENV JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/shib-jetty-base \
    JETTY_MAX_HEAP=2048m \
    JETTY_BROWSER_SSL_KEYSTORE_PASSWORD=changeme \
    JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD=changeme \
    PATH=$PATH:$JRE_HOME/bin

RUN yum -y update \
    && yum -y install which \
    # Install Amazon Corretto Java 11
    && rpm --import https://yum.corretto.aws/corretto.key \
    && curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo \
    && yum install -y java-11-amazon-corretto-devel \
    && yum -y clean all

COPY bin/ /usr/local/bin/

RUN useradd jetty -U -s /bin/false \
    && chmod 750 /usr/local/bin/run-jetty.sh /usr/local/bin/init-idp.sh

COPY --from=temp /opt/ /opt/

RUN chmod +x /opt/jetty-home/bin/jetty.sh

# expose HTTP port
EXPOSE 8080

CMD ["run-jetty.sh"]
