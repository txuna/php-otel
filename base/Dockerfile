### PHP-FPM 8.4.7 PECL 포함 빌드

FROM php:8.4.7-fpm

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions redis-6.3.0 opentelemetry
    