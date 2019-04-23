#!/bin/bash

echo "FROM buildpack-deps:$(awk -F'_' '{print tolower($2)}' <<< $LINUX_VERSION)"

echo "RUN apt-get update"

# echo "RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
# echo \"deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse\" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list && \
# apt-get -y install mongodb=3.6 mongodb-server=3.6 mongodb-shell=3.6 mongodb-mongos=3.6 mongodb-tools=3.6 && \
# service mongodb start"

echo "RUN mkdir /docker-entrypoint-initdb.d"
echo "ENV GPG_KEYS 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5"
echo "RUN set -ex; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $GPG_KEYS; do \
		gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done; \
	gpg --batch --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mongodb.gpg; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -r "$GNUPGHOME"; \
	apt-key list"

echo "ARG MONGO_PACKAGE=mongodb-org"
echo "ARG MONGO_REPO=repo.mongodb.org"
echo "ENV MONGO_PACKAGE=${MONGO_PACKAGE} MONGO_REPO=${MONGO_REPO}"
echo ""
echo "ENV MONGO_MAJOR 3.6"
echo "ENV MONGO_VERSION 3.6.12"
echo "# bashbrew-architectures:amd64 arm64v8"
echo "RUN echo \"deb http://$MONGO_REPO/apt/ubuntu xenial/${MONGO_PACKAGE%-unstable}/$MONGO_MAJOR multiverse\" | tee \"/etc/apt/sources.list.d/${MONGO_PACKAGE%-unstable}.list\""

echo "RUN set -x \
	&& apt-get update \
	&& apt-get install -y \
		${MONGO_PACKAGE}=$MONGO_VERSION \
		${MONGO_PACKAGE}-server=$MONGO_VERSION \
		${MONGO_PACKAGE}-shell=$MONGO_VERSION \
		${MONGO_PACKAGE}-mongos=$MONGO_VERSION \
		${MONGO_PACKAGE}-tools=$MONGO_VERSION \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mongodb \
	&& mv /etc/mongod.conf /etc/mongod.conf.orig"

echo "RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb"
echo "VOLUME /data/db /data/configdb"
echo "RUN mongod"

echo "RUN cd /tmp && \
wget http://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz && \
tar xzf redis-$REDIS_VERSION.tar.gz && \
cd redis-$REDIS_VERSION && \
make && \
src/redis-server --daemonize yes && \
cd .."


if [ ! -e $RUBY_VERSION_NUM ] ; then
    echo "RUN apt-get install -y libssl-dev && wget http://ftp.ruby-lang.org/pub/ruby/$(awk -F'.' '{ print $1"."$2 }' <<< $RUBY_VERSION_NUM)/ruby-$RUBY_VERSION_NUM.tar.gz && \
    tar -xzvf ruby-$RUBY_VERSION_NUM.tar.gz && \
    cd ruby-$RUBY_VERSION_NUM/ && \
    ./configure && \
    make -j4 && \
    make install && \
    ruby -v"
fi

if [ ! -e $NODE_VERSION_NUM ] ; then
    echo "RUN wget https://nodejs.org/dist/v$NODE_VERSION_NUM/node-v$NODE_VERSION_NUM.tar.gz && \
    tar -xzvf node-v$NODE_VERSION_NUM.tar.gz && \
    rm node-v$NODE_VERSION_NUM.tar.gz && \
    cd node-v$NODE_VERSION_NUM && \
    ./configure && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -r node-v$NODE_VERSION_NUM"
fi

if [ ! -e $PYTHON_VERSION_NUM ] ; then
    echo "RUN wget https://www.python.org/ftp/python/$PYTHON_VERSION_NUM/Python-$PYTHON_VERSION_NUM.tgz && \
    tar xzf Python-$PYTHON_VERSION_NUM.tgz && \
    rm Python-$PYTHON_VERSION_NUM.tgz && \
    cd Python-$PYTHON_VERSION_NUM && \
    ./configure && \
    make install"
fi

# if [ ! -e $PHP_VERSION_NUM ] ; then
#     wget "http://php.net/distributions/php-${PHP_VERSION_NUM}.tar.xz"
# fi

if [ $JAVA = "true" ] ; then
cat << EOF
RUN if [ \$(grep 'VERSION_ID="8"' /etc/os-release) ] ; then \\
    echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list && \\
    apt-get update && apt-get -y install -t jessie-backports openjdk-8-jdk ca-certificates-java \\
; elif [ \$(grep 'VERSION_ID="9"' /etc/os-release) ] ; then \\
		apt-get update && apt-get -y -q --no-install-recommends install -t stable openjdk-8-jdk ca-certificates-java \\
; elif [ \$(grep 'VERSION_ID="14.04"' /etc/os-release) ] ; then \\
		apt-get update && \\
    apt-get --force-yes -y install software-properties-common python-software-properties && \\
    echo | add-apt-repository -y ppa:webupd8team/java && \\
    apt-get update && \\
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \\
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \\
    apt-get -y install oracle-java8-installer \\
; elif [ \$(grep 'VERSION_ID="16.04"' /etc/os-release) ] ; then \\
    apt-get update && \\
    apt-get --force-yes -y install software-properties-common python-software-properties && \\
    echo | add-apt-repository -y ppa:webupd8team/java && \\
    apt-get update && \\
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \\
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \\
    apt-get -y install oracle-java8-installer \\
; fi
EOF
fi

if [ $MYSQL_CLIENT = "true" ] ; then
    echo "RUN apt-get -y install mysql-client"
fi

if [ $POSTGRES_CLIENT = "true" ] ; then
    echo "RUN apt-get -y install postgresql-client"
fi

if [ $DOCKERIZE = "true" ] ; then
DOCKERIZE_VERSION="v0.6.1"

cat << EOF
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \\
    tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \\
    rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz
EOF
fi


# install bats for testing
echo "RUN git clone https://github.com/sstephenson/bats.git \
  && cd bats \
  && ./install.sh /usr/local \
  && cd .. \
  && rm -rf bats"

# install dependencies for tap-to-junit
echo "RUN perl -MCPAN -e 'install TAP::Parser'"
echo "RUN perl -MCPAN -e 'install XML::Generator'"

# install lsb-release, etc., for testing linux distro
echo "RUN apt-get update && apt-get -y install lsb-release unzip"

if [ $BROWSERS = "true" ] ; then
cat << EOF
RUN if [ \$(grep 'VERSION_ID="8"' /etc/os-release) ] ; then \\
    echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list && \\
    apt-get update && apt-get -y install -t jessie-backports xvfb phantomjs \\
; else \\
		apt-get update && apt-get -y install xvfb phantomjs \\
; fi
EOF
echo "ENV DISPLAY :99"

echo "# install firefox
RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/firefox.deb https://s3.amazonaws.com/circle-downloads/firefox-mozilla-build_47.0.1-0ubuntu1_amd64.deb \
  && echo 'ef016febe5ec4eaf7d455a34579834bcde7703cb0818c80044f4d148df8473bb  /tmp/firefox.deb' | sha256sum -c \
  && dpkg -i /tmp/firefox.deb || apt-get -f install  \
  && apt-get install -y libgtk3.0-cil-dev libasound2 libasound2 libdbus-glib-1-2 libdbus-1-3 \
  && rm -rf /tmp/firefox.deb"

echo "# install chrome
RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && (dpkg -i /tmp/google-chrome-stable_current_amd64.deb || apt-get -fy install)  \
  && rm -rf /tmp/google-chrome-stable_current_amd64.deb \
  && sed -i 's|HERE/chrome\"|HERE/chrome\" --disable-setuid-sandbox --no-sandbox|g' \
       \"/opt/google/chrome/google-chrome\""

echo "# install chromedriver
RUN apt-get -y install libgconf-2-4 \
  && curl --silent --show-error --location --fail --retry 3 --output /tmp/chromedriver_linux64.zip \"http://chromedriver.storage.googleapis.com/2.33/chromedriver_linux64.zip\" \
  && cd /tmp \
  && unzip chromedriver_linux64.zip \
  && rm -rf chromedriver_linux64.zip \
  && mv chromedriver /usr/local/bin/chromedriver \
  && chmod +x /usr/local/bin/chromedriver"
fi
