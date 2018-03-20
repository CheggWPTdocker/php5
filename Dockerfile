FROM php:5.6.34-fpm-alpine3.4
LABEL maintainer="Joel Gilley jgilley@chegg.com"

ENV TIMEZONE=UTC \
	ENV=/etc/profile \
	APP_ENV=development

# dumb-init
# tidyhtml-libs tidyhtml
# tidyhtml-dev
RUN apk --update add  ca-certificates nginx supervisor bash && \
	apk add --virtual .build_package git curl build-base autoconf dpkg-dev \
		file libmagic re2c cmake dpkg && \
	apk add --virtual .deps_run libxpm freetype xextproto inputproto xtrans \
		libwebp libxext libxt libx11 libxcb libxau libsm libice libxdmcp \
		libbsd xproto libuuid kbproto libpthread-stubs libpng \
		libmemcached-libs zlib freetds unixodbc readline libpq \
		gettext-asprintf gettext-libs libintl gettext libunistring libldap zlib \
		icu-libs libmemcached cyrus-sasl libmcrypt hiredis gmp && \
	apk add --virtual .build_deps libxau-dev libbsd-dev libxdmcp-dev libxcb-dev \
		libx11-dev libxext-dev libice-dev libsm-dev libxt-dev libxpm-dev libpng-dev \
		freetype-dev libjpeg-turbo-dev libwebp-dev bzip2-dev gettext-dev gmp-dev \
		icu-dev freetds-dev postgresql-dev libxml2-dev zlib-dev \
		libmemcached-dev cyrus-sasl-dev libmcrypt-dev hiredis-dev tzdata

RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
	echo "${TIMEZONE}" > /etc/timezone && \
	update-ca-certificates && \
	rm -rf /etc/nginx/conf.d/default.conf && \
	mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
	echo alias dir=\'ls -alh --color\' >> /etc/profile && \
	echo 'source ~/.profile' >> /etc/profile && \
	echo 'cat /etc/os-release' >> ~/.profile && \
	mkdir -p /webroot /run/nginx && \
	chown -R nginx:www-data /run/nginx && \
	chown -R :www-data /webroot && \
	chmod -R g+rw /webroot

ENV tidy_version=5.6.0
RUN echo INSTALL TIDY-HTML5 LIBRARY && \
 	git clone --branch ${tidy_version} --depth 1 https://github.com/htacg/tidy-html5.git /tmp/tidy-html5 && \
	cd /tmp/tidy-html5/build/cmake/ && \
	cmake ../.. -DCMAKE_BUILD_TYPE=Release && \
	make && make install && \
	ln -s /usr/local/include/tidybuffio.h /usr/local/include/buffio.h && \
	cd && rm -rf /tmp/tidy-html5

# Install known pacakages with docker-php-ext-install, install others with pecl install
RUN echo INSTALL DOCKER-PHP-EXT AVAILABLE MODULES && \
	docker-php-ext-install -j4 bcmath bz2 gd gettext gmp intl mysqli mcrypt \
	pdo_dblib pdo_pgsql pdo_mysql session soap tidy opcache xmlrpc zip
RUN echo INSTALL PECL APCU MODULES && \
	yes "" | pecl install apcu-4.0.11 && \
	echo "extension=apcu.so" > /usr/local/etc/php/conf.d/pecl-php-ext-apcu.ini
RUN echo INSTALL PECL MEMCACHED MODULES && \
	yes "" | pecl install memcached-2.2.0 && \
	echo "extension=memcached.so" > /usr/local/etc/php/conf.d/pecl-php-ext-memcached.ini

# Install phpiredis
ENV phpredis_version=4.0.0
RUN echo INSTALL PHPREDIS PHP MODULE && \
	git clone --branch ${phpredis_version} --depth 1 https://github.com/phpredis/phpredis.git /tmp/phpredis && \
	cd /tmp/phpredis && \
	phpize && ./configure && make && make install && \
	echo "extension=redis.so" > /usr/local/etc/php/conf.d/source-php-ext-phpredis.ini && \
	cd && rm -rf /tmp/phpredis

# Install tideways
ENV tideways_version=1.5.3 \
	tideways_ext_version=4.1.5 \
	tideways_php_version=2.0.16 \
	tideways_dl=https://github.com/tideways/ \
	TIDEWAYS_PORT_UDP=8135 \
	TIDEWAYS_PORT_TCP=9135 \
	TIDEWAYS_ENV=production
RUN echo INSTALL TIDEWAYS PHP MODULE && \
	curl -L "${tideways_dl}/php-profiler-extension/archive/v${tideways_ext_version}.zip" \
	--output "/tmp/v${tideways_ext_version}.zip" && \
	cd /tmp && unzip "v${tideways_ext_version}.zip" && \
	cd "php-xhprof-extension-${tideways_ext_version}" && \
	phpize && \
	./configure && \
	make && make install && \
	cd /tmp && rm -rf php-xhprof-extension-${tideways_ext_version}/ v${tideways_ext_version}.zip && \
	echo "extension=tideways.so" > /usr/local/etc/php/conf.d/source-php-ext-tideways.ini && \
echo INSTALL TIDEWAYS PROFILER && \
	curl -L "${tideways_dl}/profiler/releases/download/v${tideways_php_version}/Tideways.php" \
	--output "$(php-config --extension-dir)/Tideways.php" && \
	ls -l "$(php-config --extension-dir)/Tideways.php" && \
echo INSTALL TIDEWAYS DAEMON && \
	curl -L "https://s3-eu-west-1.amazonaws.com/tideways/daemon/${tideways_version}/tideways-daemon-v${tideways_version}-alpine.tar.gz" \
	--output "/tmp/tideways-daemon-v${tideways_version}-alpine.tar.gz" && \
	cd /tmp && tar -zxf tideways-daemon-v${tideways_version}-alpine.tar.gz && \
	mv build/dist/tideways-daemon /usr/bin && \
	ls -l /usr/bin/tideways-daemon && \
	mkdir -p /var/run/tideways && \
	cd /tmp && rm -rf build/ tideways-daemon-v${tideways_version}-alpine.tar.gz

# Install dumb-init
ENV dumbinit_version=1.2.1
RUN echo INSTALL DUMB-INIT PID HANDLER && \
	wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${dumbinit_version}/dumb-init_${dumbinit_version}_amd64 && \
	chmod +x /usr/local/bin/dumb-init

# Add the process control directories for PHP
# make it user/group read write
RUN mkdir -p /run/php && \
	chown -R www-data:www-data /run/php

# Report on PHP build
RUN php -m && \
	php -v

# clean up apk
RUN apk del .build_deps && \
	apk del .build_package && \
	rm -rf /var/cache/apk/*

# Add the config files
COPY container_confs /
RUN chmod a+x /entrypoint.sh /wait-for-it.sh /start_tideways.sh

WORKDIR /webroot

# Expose the ports for nginx
EXPOSE 80 443

# the entry point definition
ENTRYPOINT ["/entrypoint.sh"]

# default command for entrypoint.sh
CMD ["supervisor"]
