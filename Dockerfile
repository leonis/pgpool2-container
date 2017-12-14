##### gosu
FROM alpine:3.6 as gosu
ENV GOSU_VERSION 1.10
RUN set -ex; \
  \
  apk add --no-cache --virtual .gosu-deps \
    dpkg \
    gnupg \
    openssl \
  ; \
  \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  chmod +x /usr/local/bin/gosu; \
  gosu nobody true; \
  apk del .gosu-deps

##### pgpool2
FROM alpine:3.6
ENV PGPOOL_VERSION 3.7.0
ENV PG_VERSION 9.6.6-r0
ENV LANG en_US.utf8
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu
RUN apk --update --no-cache --virtual .build-deps add \
        postgresql-dev=${PG_VERSION} linux-headers gcc make libgcc g++ libmemcached-dev cyrus-sasl-dev && \
    apk --update --no-cache add libpq=${PG_VERSION} postgresql-client=${PG_VERSION} libmemcached-libs \
        libffi-dev python python-dev py2-pip && \
    cd /tmp && \
    wget http://www.pgpool.net/mediawiki/images/pgpool-II-${PGPOOL_VERSION}.tar.gz -O - | tar -xz && \
    chown root:root -R /tmp/pgpool-II-${PGPOOL_VERSION} && \
    cd /tmp/pgpool-II-${PGPOOL_VERSION} && \
    ./configure --prefix=/usr \
                --sysconfdir=/etc \
                --mandir=/usr/share/man \
                --infodir=/usr/share/info \
                --with-memcached=/usr && \
    make && \
    make install && \
    rm -rf /tmp/pgpool-II-${PGPOOL_VERSION} && \
    cd /tmp && \
    apk del .build-deps && \
    pip install Jinja2 && \
    mkdir /etc/pgpool2 /var/run/pgpool /var/log/pgpool /var/run/postgresql /var/log/postgresql/ && \
    chown postgres /etc/pgpool2 /var/run/pgpool /var/log/pgpool /var/run/postgresql /var/log/postgresql

# Post Install Configuration.
ADD bin/configure-pgpool2 /usr/bin/configure-pgpool2
RUN chmod +x /usr/bin/configure-pgpool2
ADD conf/pcp.conf.template /usr/share/pgpool2/pcp.conf.template
ADD conf/pgpool.conf.template /usr/share/pgpool2/pgpool.conf.template

# Start the container.
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9999 9898

CMD ["pgpool","-n", "-f", "/etc/pgpool2/pgpool.conf", "-F", "/etc/pgpool2/pcp.conf"]
