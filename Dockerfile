FROM alpine:edge
# FROM alpine:3.4
MAINTAINER jgilley@chegg.com

# set our environment
ENV APP_ENV='DEVELOPMENT'
# ENV APP_ENV='PRODUCTION'
ENV php_ini_dir /etc/php5/conf.d
ENV php_ini /etc/php5/php.ini

# if edge libraries are needed use the following:
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# install base packages - BASH should only be used for debugging, it's almost a meg in size
# install ca-certificates
# clean up the apk cache (no-cache still caches the indexes)
# update the ca-certificates
RUN	apk --update \
	add bash ca-certificates openssl supervisor && \
	update-ca-certificates

RUN	apk add \
	--virtual .build_package \
		git curl file build-base autoconf

RUN apk add \
	--virtual .php_service \
		mysql-client \
		php5 \
		php5-bcmath \
		php5-bz2 \
		php5-ctype \
		php5-curl \
		php5-dom \
		php5-fpm \
		php5-gd \
		php5-gettext \
		php5-gmp \
		php5-intl \
		php5-iconv \
		php5-json \
		php5-mcrypt \
		php5-mysqli \
		php5-openssl \
		php5-pdo \
		php5-pdo_dblib \
		php5-pdo_mysql \
		php5-pdo_pgsql \
		php5-pdo_sqlite \
		php5-phar \
		php5-soap \
		php5-sqlite3 \
		php5-xmlreader \
		php5-xmlrpc \
		php5-zip

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-php5-memcached/master/sgerrand.rsa.pub && \
	wget https://github.com/sgerrand/alpine-pkg-php5-memcached/releases/download/2.2.0-r0/php5-memcached-2.2.0-r0.apk && \
	apk add php5-memcached-2.2.0-r0.apk

# Add the container config files
COPY container_confs /

# create the supervisor run dir
# make sure that entrypoint and other scripts are executeable
RUN mkdir -p /run/supervisord && \
	ln -s /usr/bin/php5 /usr/bin/php && \
	ln -s /usr/bin/phpize5 /usr/bin/phpize && \
	mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
	chmod +x /entrypoint.sh /wait-for-it.sh /etc/profile /etc/profile.d/*.sh

# Add the www-data user and group, fail on error
RUN set -x ; \
	addgroup -g 82 -S www-data ; \
	adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

# Configure PHP
# dont display errors 	sed -i -e 's/display_errors = Off/display_errors = On/g' ${php_ini} && \
# fix path off
# error log becomes stderr
# Enable php-fpm on nginx virtualhost configuration
RUN	sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' ${php_ini} && \
	sed -i -e 's/;error_log = php_errors.log/error_log = \/proc\/self\/fd\/1/g' ${php_ini}

# Add the process control dirs for php
# make it user/group read write
RUN mkdir -p /run/php && \
	chown -R www-data:www-data /run/php

# dump some build done info on PHP
RUN php -m && php --ini

# Clean up the apk cache and tmp just in case
RUN rm -rf /var/cache/apk/* && \
	rm -rf /tmp/*

# Expose the ports for nginx
EXPOSE 9000

# the entry point definition
ENTRYPOINT ["/entrypoint.sh"]

# default command for entrypoint.sh
CMD ["supervisor"]
