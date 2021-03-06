FROM alpine:latest

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    ip6tables \
    iptables \
    jq \
    openssl \
    wireguard-tools \
    nano \
	findutils \
	p7zip \
	python3 \
	rsync \
	tar \
	transmission-cli \
	transmission-daemon \
	unrar \
    socat \
	unzip && \
    curl -o \
	    /tmp/combustion.zip -L \
	    "https://github.com/Secretmapper/combustion/archive/release.zip" && \
    unzip \
	    /tmp/combustion.zip -d \
	    / && \
    mkdir -p /tmp/twctemp && \
    TWCVERSION=$(curl -sX GET "https://api.github.com/repos/ronggang/transmission-web-control/releases/latest" \
        | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    curl -o \
        /tmp/twc.tar.gz -L \
        "https://github.com/ronggang/transmission-web-control/archive/${TWCVERSION}.tar.gz" && \
    tar xf \
        /tmp/twc.tar.gz -C \
        /tmp/twctemp --strip-components=1 && \
    mv /tmp/twctemp/src /transmission-web-control && \
    mkdir -p /kettu && \
    curl -o \
        /tmp/kettu.tar.gz -L \
        "https://github.com/endor/kettu/archive/master.tar.gz" && \
    tar xf \
        /tmp/kettu.tar.gz -C \
        /kettu --strip-components=1 && \
    echo "**** cleanup ****" && \
    rm -rf \
        /tmp/*

ENV LOCAL_NETWORK= \
    KEEPALIVE=0 \
    VPNDNS= \
    PIA_USER= \
    PIA_PASS=\
    PIA_PF=true\
    TRANSUSER=\
    TRANSPASS=\
    TRANSMISSION_WEB_HOME="/combustion-release"\
    FORWARD_PORTS="9091,8888"



# The PIA desktop app uses this public key to verify server list downloads
# https://github.com/pia-foss/desktop/blob/master/daemon/src/environment.cpp#L30
COPY ./RegionsListPubKey.pem /RegionsListPubKey.pem

# ports and volumes
EXPOSE 9091 51413
VOLUME /config /downloads /watch


# Add main work dir to PATH
WORKDIR /scripts

# copy local files
COPY root/ /
RUN chmod 755 /scripts/*

# Get the PIA CA cert
ADD https://raw.githubusercontent.com/pia-foss/desktop/master/daemon/res/ca/rsa_4096.crt /scripts/ca.rsa.4096.crt

# HEALTHCHECK --interval=5m CMD /scripts/healthcheck.sh

EXPOSE 9091

# HEALTHCHECK --interval=5m CMD /scripts/healthcheck.sh
CMD ["/scripts/runme.sh"]
#ENTRYPOINT [ "/bin/sh" ]