FROM php:8.2-fpm-alpine

# Install docker CLI and tools we need to adjust user/group at runtime
RUN apk add --no-cache docker-cli bash curl shadow coreutils \
    oniguruma-dev libzip-dev $PHPIZE_DEPS \
 && docker-php-ext-configure zip \
 && docker-php-ext-install -j"$(nproc)" mysqli pdo_mysql mbstring zip

WORKDIR /var/www/html

# Copy entrypoint that fixes permissions to access /var/run/docker.sock
COPY web/php/docker-entry.sh /usr/local/bin/docker-entry.sh
RUN chmod +x /usr/local/bin/docker-entry.sh \
    && sed -i 's/\r$//' /usr/local/bin/docker-entry.sh

# The code will be mounted at runtime from ../web/public
# Expose php-fpm on 9000 (default for this image)
CMD ["/usr/local/bin/docker-entry.sh"]
