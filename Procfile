php-fpm: exec php-fpm -y $DEVSHELL_DIR/php-fpm/php-fpm.conf
caddy: XDG_DATA_HOME=$DEVSHELL_STATE_DIR/caddy/data XDG_CONFIG_HOME=$DEVSHELL_STATE_DIR/caddy/config exec caddy run --config $DEVSHELL_DIR/caddy/Caddyfile
npm-watch: exec npm run watch