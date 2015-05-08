FROM ubuntu:trusty
MAINTAINER Paul Czarkowski "paul@paulcz.net"

# -----------------------------------------------------------------------------
# Environment variables
# -----------------------------------------------------------------------------
ENV INITRD No
ENV FAKE_CHROOT 1
RUN \
  dpkg-divert --remove /usr/bin/ischroot && \
  dpkg-divert --add --rename --divert /usr/bin/ischroot.original /usr/bin/ischroot
ADD build/ischroot /usr/bin/ischroot
RUN chmod 755 /usr/bin/ischroot

ADD build/policy-rc.d /usr/sbin/policy-rc.d
RUN chmod +x /usr/sbin/policy-rc.d

RUN echo 'force-unsafe-io' | tee /etc/dpkg/dpkg.cfg.d/02apt-speedup
RUN echo 'DPkg::Post-Invoke {"/bin/rm -f /var/cache/apt/archives/*.deb || true";};' | tee /etc/apt/apt.conf.d/no-cache
RUN echo 'Acquire::http {No-Cache=True;};' | tee /etc/apt/apt.conf.d/no-http-cache

ENV TZ Europe/Zurich
ENV CONFD_VERSION 0.9.0
ENV ETCDCTL_VERSION 2.0.10

# -----------------------------------------------------------------------------
# Pre-install
# -----------------------------------------------------------------------------
RUN apt-get update -qqy
RUN \
  apt-get install -qqy --no-install-recommends \
  make \
  ca-certificates \
  net-tools \
  sudo \
  wget \
  vim \
  strace \
  lsof \
  netcat \
  lsb-release \
  locales \
  socat \
  curl

RUN \
  touch /etc/default/locale && \
  echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
  echo "LANG=en_US.UTF-8" >> /etc/default/locale && \
  locale-gen en_US.UTF-8

RUN \
  apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A || \
  apt-key adv --keyserver hkp://keys.gnupg.net:80 --recv-keys 1C4CBDCDCD2EFD2A

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
RUN \
  echo "deb http://repo.percona.com/apt `lsb_release -cs` main" > /etc/apt/sources.list.d/percona.list && \
  echo "deb-src http://repo.percona.com/apt `lsb_release -cs` main" >> /etc/apt/sources.list.d/percona.list && \
  ln -fs /bin/true /usr/bin/chfn && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y percona-xtradb-cluster-client-5.6 percona-xtradb-cluster-server-5.6  percona-xtrabackup rsync percona-xtradb-cluster-garbd-3.x haproxy && \
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf && \
  rm -rf /var/lib/mysql/*

RUN \
  curl -s -L https://github.com/coreos/etcd/releases/download/v$ETCDCTL_VERSION/etcd-v$ETCDCTL_VERSION-linux-amd64.tar.gz -o /usr/local/bin/etcdctl.tgz && \
  tar -zxf /usr/local/bin/etcdctl.tgz -C /usr/local/bin && \
  mv /usr/local/bin/etcd-v$ETCDCTL_VERSION-linux-amd64/etcd* /usr/local/bin && \
  rm /usr/local/bin/etcdctl.tgz && \
  rm -fr /usr/local/bin/etcd-v$ETCDCTL_VERSION-linux-amd64 && \
  chown root: /usr/local/bin/etcd*

RUN \
  curl -s -L https://github.com/kelseyhightower/confd/releases/download/v$CONFD_VERSION/confd-$CONFD_VERSION-linux-amd64 -o /usr/local/bin/confd && \
  chmod +x /usr/local/bin/confd

# -----------------------------------------------------------------------------
# Post-install
# -----------------------------------------------------------------------------
ADD . /app
RUN chmod +x /app/bin/*
WORKDIR /app

VOLUME ["/var/lib/mysql"]
EXPOSE 3306 4444 4567 4568
CMD ["/app/bin/boot"]

# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*