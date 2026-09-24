ARG REGISTRY=localhost:5001
ARG BASE_TAG=latest

FROM ${REGISTRY}/base:${BASE_TAG}

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY src/php-fpm /var/www/html

RUN composer install