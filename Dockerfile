# The symfonix-builder image is built using Nix and contains all the necessary packages
# to perform a production build of our Symfony project.
FROM symfonix-builder:latest as builder

#COPY . /srv/app

#ENV COMPOSER_ALLOW_SUPERUSER=1
#ENV PATH="${PATH}:/root/.composer/vendor/bin"

# Creating users using Nix' dockerTools is cumbersome.
# Create one during our docker build so we can copy the /etc/passwd and /etc/group files into our production images.
RUN useradd -M --system --uid 666 www-data

# Npm scripts often contain the `#!/usr/bin/env sh` shebang, which will fail because there's no `/usr/bin/env`.
# Symlink `/usr/bin/env` to `/sbin/env` to fix this.
RUN #mkdir -p /usr/bin && ln -s /sbin/env /usr/bin/env

#RUN set -eux; \
#    cd /srv/app; \
#    mkdir -p /tmp var/cache var/log; \
#    /bin/composer install --prefer-dist --no-progress --no-interaction; \
#    /bin/composer dump-autoload --classmap-authoritative --no-dev; \
#    /bin/composer dump-env prod; \
#    /bin/composer run-script --no-dev post-install-cmd; \
#    chmod +x bin/console; \
#    /bin/npm ci; \
#    /bin/npm run build; \
#    chown -R www-data:www-data .; \
#    mkdir -p /var/run/php && chown www-data:www-data /var/run/php; sync

RUN set -eux; \
    mkdir -p /var/run/php && chown www-data:www-data /var/run/php; \
    mkdir -p /srv/caddy/{data,config} && chown -R www-data:www-data /srv/caddy


FROM symfonix-php-base:latest as symfonix-php

COPY --from=builder --link /etc/passwd /etc/passwd
COPY --from=builder --link /etc/group /etc/group
#COPY --from=builder --link /srv/app /srv/app
COPY --from=builder --link /var/run /var/run


COPY docker/php-fpm/php-fpm.conf /etc/php-fpm.d/php-fpm.conf

VOLUME /var/run/php
VOLUME /share/php/symfonix/var

STOPSIGNAL SIGQUIT
WORKDIR /share/php/symfonix
USER www-data
EXPOSE 9000

CMD ["php-fpm", "-y", "/etc/php-fpm.d/php-fpm.conf"]

FROM symfonix-caddy-base:latest as symfonix-caddy

COPY --from=builder --link /etc/passwd /etc/passwd
COPY --from=builder --link /etc/group /etc/group
COPY --from=builder --link /srv/caddy /srv/caddy
#COPY --from=builder --link /srv/app/public /srv/app/public/
COPY docker/caddy/Caddyfile /etc/caddy/Caddyfile

ENV XDG_CONFIG_HOME /srv/caddy/config
ENV XDG_DATA_HOME /srv/caddy/data

WORKDIR /share/php/symfonix
USER www-data

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]