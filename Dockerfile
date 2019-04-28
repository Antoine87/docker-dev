FROM scratch

# Install Alpine Linux
ADD alpine-minirootfs-3.9.3-x86_64.tar.gz /

# Configure timezone
RUN set -xe; \
    apk add --no-cache --virtual .timezone tzdata; \
    cp /usr/share/zoneinfo/Europe/Paris /etc/localtime; \
    echo "Europe/Paris" > /etc/timezone; \
    apk del --no-network .timezone

# -------------------------------------------------------------------------------

# Set persistent build environment variables for PHP
ENV _PHP_SRC_URL="https://www.php.net/get/php-7.3.4.tar.xz/from/this/mirror" \
    _PHP_SRC_SHA256="6fe79fa1f8655f98ef6708cde8751299796d6c1e225081011f4104625b923b83" \
    _PHP_INI_DIR="/usr/local/etc/php" \
    _PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
    _PHP_CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
    _PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

RUN set -xe; \
# Download sources and check content
    mkdir /tmp/php; \
    cd /tmp/php; \
    wget --quiet --output-document php.tar.xz "$_PHP_SRC_URL"; \
    echo "$_PHP_SRC_SHA256 *php.tar.xz" | sha256sum -c; \
    \
# Extract sources
    tar --extract --file php.tar.xz --strip-components=1; \
    \
# Install build automation package dependencies
    apk update; \
    apk add --no-cache --virtual .build-dependencties \
        autoconf \
        bison \
        file \
        g++ \
        libtool \
        libxml2-dev \
        make \
        openssl-dev \
        re2c \
    ; \
# Configure the build automation
    export CFLAGS="$_PHP_CFLAGS" \
           CPPFLAGS="$_PHP_CPPFLAGS" \
           LDFLAGS="$_PHP_LDFLAGS"; \
    ./configure \
        --with-config-file-path="$_PHP_INI_DIR" \
        --with-config-file-scan-dir="$_PHP_INI_DIR/conf.d" \
        --enable-option-checking=fatal \
        --disable-all \
        --disable-cgi \
        --disable-phpdbg \
        --enable-ctype \
        --enable-dom \
        --enable-filter \
        --enable-hash \
        --enable-json \
        --enable-libxml \
        --enable-mbstring \
        --enable-pdo \
        --enable-phar \
        --enable-simplexml \
        --enable-tokenizer \
        --enable-xml \
        --enable-xmlwriter \
        --with-iconv\
        --with-openssl \
        --with-pdo-sqlite \
        --with-sqlite3 \
        --with-zlib \
    ; \
# Run the build automation
    make --jobs=$(expr $(nproc) + 1); \
    make install; \
    make clean; \
    \
# Copy default ini files
    mkdir -p "$_PHP_INI_DIR/conf.d"; \
    cp php.ini-* "$_PHP_INI_DIR/"; \
    \
# Cleanup all the build process
    apk del --no-network .build-dependencties; \
    cd /; \
    rm -Rf /tmp/php /tmp/pear

RUN set -xe; \
# Install PHP runtime dependencies permanently
    apk add \
        libxml2 \
    ; \
# Create user+group of the PHP cli server
    addgroup -g 82 -S www-data; \
    adduser -u 82 -D -S -G www-data www-data; \
    \
# Install default entrypoint page
    mkdir -p /srv/web/public; \
    echo '<?php phpinfo();' > /srv/web/public/index.php; \
    chown -R www-data:www-data /srv/web; \
    chmod -R 777 /srv/web

COPY php.ini /usr/local/etc/php/php.ini
COPY entrypoint /usr/local/bin/entrypoint

WORKDIR /srv/web

# -------------------------------------------------------------------------------

RUN set -xe; \
    wget --quiet --output-document /tmp/composer-setup.php \
        https://raw.githubusercontent.com/composer/getcomposer.org/cb19f2aa3aeaa2006c0cd69a7ef011eb31463067/web/installer; \
    php -r " \
        \$signature = '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5'; \
        \$hash = hash('sha384', file_get_contents('/tmp/composer-setup.php')); \
        if (!hash_equals(\$signature, \$hash)) { \
            echo 'ERROR: Invalid installer signature.' . PHP_EOL; \
            exit(1); \
        }" \
    ; \
    php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer; \
    composer --version; \
    su -c "composer --version" -s /bin/sh www-data; \
    cp ~/.composer/keys.dev.pub ~/.composer/keys.tags.pub /home/www-data/.composer; \
    su -c "composer --ansi diagnose" -s /bin/sh www-data; \
    rm -f /tmp/composer-setup.php

USER www-data

CMD ["/bin/sh"]
