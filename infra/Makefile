# This sets the recipe prefix to one or more spaces
.RECIPEPREFIX +=
.DEFAULT_GOAL := help
.PHONY: *

PHP_OS ?= alpine
ifneq ("$(wildcard ./.env)","")
  PHP_OS=$(shell sed '/PHP_OS=/!d' .env | sed 's/PHP_OS=//')
endif

WWW_UID ?= $(shell id -u)
WWW_GID ?= $(shell id -g)

NO_COLOR=\033[0m
OK_COLOR=\033[32m
ERROR_COLOR=\033[31m
WARN_COLOR=\033[33m

help:
    @echo "${WARN_COLOR}Usage:${NO_COLOR}\n  make [target] [arg=\"val\"...]\n\n${WARN_COLOR}Targets:${NO_COLOR}"
    @grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  ${OK_COLOR}%-15s${NO_COLOR} %s\n", $$1, $$2}'

# Make sure to run the given command in a container identified by the given service
#
# $(1) the Docker Compose service
# $(2) the command to run
#
define run-in-container
    docker-compose exec $(1) $(2)
endef

# Run php command in the php container
#
# $(1) the command to run
#
define run-php
    @$(call run-in-container,php,php -dmemory_limit=-1 $(1))
endef

define setup-permissions
    groupmod -o -g ${WWW_GID} www-data \
    && usermod -g ${WWW_GID} -u ${WWW_UID} -d /home/www-data www-data \
    && useradd --gid ${WWW_GID} --groups www-data nginx | : \
    && chown -R www-data:www-data /home/www-data \
    && chown -R www-data:www-data /var/www/project
endef

fix-permissions: ## To fix the permissions
    @echo "${WARN_COLOR}Fix permissions${NO_COLOR}"
    @docker-compose exec --user=root php /bin/bash -c "$(setup-permissions)"
    @if [ "${PHP_OS}" = "alpine-mac" ]; then \
        docker-compose exec php /bin/bash -c "mkdir -p var/cache && mkdir -p var/log" ; \
    fi

setup: ## To setup environment and permissions
    @echo "${WARN_COLOR}Setup environment${NO_COLOR}"
    @cp -n php/composer-auth.json.dist php/composer-auth.json | :
    @cp -n php/xdebug.ini.dist php/xdebug.ini | :
    @echo "COMPOSE_PROJECT_NAME=project" > .env
    @echo "COMPOSE_FILE=docker-compose-${PHP_OS}.yml" >> .env
    @echo "PHP_OS=${PHP_OS}" >> .env
    @echo "USER_ID=${WWW_UID}" >> .env
    @echo "GROUP_ID=${WWW_GID}" >> .env
    @echo "${WARN_COLOR}Creating containers${NO_COLOR}"
    @docker-compose -f docker-compose-alpine.yml -f docker-compose-alpine-mac.yml -f selenium/docker-compose.yml down
    @docker container prune --filter label=com.docker.compose.project=project --force
    @docker volume prune --filter label=com.docker.compose.project=project --force
    @-make infra-up
    @echo "${WARN_COLOR}Waiting for containers to be ready...${NO_COLOR}"
    @( docker-compose logs -f database  & ) | grep -q 'database system is ready to accept connections' > /dev/null
    @-make fix-permissions
    @docker-compose restart php
    @echo "${WARN_COLOR}Done!${NO_COLOR}"
    @echo "${OK_COLOR}You can now install the vendors ('make app-vendors-install')${NO_COLOR}"

########################################
#              INFRA                   #
########################################

infra-shell-php-fpm: ## To open a shell session in the php_fpm container
    @docker-compose exec php /bin/sh

infra-shell-php-fpm-root: ## To open a shell session in the php_fpm container with root user
    @docker-compose exec --user=root php /bin/sh

infra-psql: ## Run psql
    @docker-compose exec database psql -U postgres

infra-show-containers: ## To show all the containers
    @docker-compose -f docker-compose-${PHP_OS}.yml -f selenium/docker-compose.yml ps

infra-stop: ## To stop all the containers
    @docker-compose -f docker-compose-alpine.yml -f docker-compose-alpine-mac.yml -f selenium/docker-compose.yml stop
    @if [ "${PHP_OS}" = "alpine-mac" ]; then \
        echo 'Stopping docker-sync ...'; \
        docker-sync stop; \
    fi

infra-up: ## To start all the containers
    @-make infra-stop
    @if [ "${PHP_OS}" = "alpine-mac" ]; then \
        docker-sync start; \
    fi
    @docker-compose up -d
    @if [ "${PHP_OS}" = "alpine-mac" ]; then \
        make fix-permissions && make infra-stop && docker-sync start; \
        docker-compose up -d ; \
    fi

########################################
#                APP                   #
########################################

app-vendors-install: ## To install vendors
    @docker-compose restart php
# composer parallel install plugin
    @docker-compose exec php /bin/bash -c "composer global require hirak/prestissimo"
    @docker-compose exec php /bin/bash -c "if [ -f composer.json ]; then composer install; fi"
    @echo "${WARN_COLOR}Done!${NO_COLOR}"
    @echo "${OK_COLOR}You can now install the app ('make app-install') or restore database (prepare infra/db/pg_dump.tar.gz and run 'make db-restore')${NO_COLOR}"

app-install: ## To install app
    @echo "${WARN_COLOR}Done!${NO_COLOR}"

app-clear-cache: ## To clear the cache
    @docker-compose exec php /bin/bash -c "rm -rf var/cache/*"

#assets
app-assets-generate: ## To generate assets
    @docker-compose exec php php app/console assetic:dump

app-assets-reset: ## To clear cache and generate assets
    @make app-clear-cache
    @make app-assets-generate

########################################
#                DB                    #
########################################

parallel=4

define db-dump-cmd
    rm -rf /tmp/pg_dump /tmp/pg_dump.tar.gz \
    && mkdir /tmp/pg_dump \
    && pg_dump -U postgres -j ${parallel} -Fd -f /tmp/pg_dump project \
    && cd /tmp \
    && tar -czf pg_dump.tar.gz pg_dump/*
endef

define db-restore-cmd
    rm -rf /tmp/pg_dump \
    && cd /tmp \
    && tar -xzf pg_dump.tar.gz \
    && pg_restore -U postgres -d project -Fd -j ${parallel} -x /tmp/pg_dump \
    && rm -rf /tmp/pg_dump /tmp/pg_dump.tar.gz
endef

db-dump: ## Dumps the DB to an SQL file on the host
    @echo "${WARN_COLOR}Dumping database, this can take a bit of time...${NO_COLOR}"
    @docker-compose exec database /bin/bash -c '${db-dump-cmd}'
    @docker cp `docker-compose ps -q database`:/tmp/pg_dump.tar.gz ./db/pg_dump.tar.gz
    @docker-compose exec database /bin/bash -c 'rm -rf /tmp/pg_dump /tmp/pg_dump.tar.gz'
    @echo "${OK_COLOR}Done!${NO_COLOR}"

db-restore: ## Restores the DB from the dump on the host
    @echo "${WARN_COLOR}Restoring database, this can take a bit of time...${NO_COLOR}"
    @docker cp ./db/pg_dump.tar.gz `docker-compose ps -q database`:/tmp/pg_dump.tar.gz
    @docker-compose exec database /bin/bash /docker-entrypoint-initdb.d/init-user-db.sh
    @docker-compose exec database /bin/bash -c '${db-restore-cmd}'
    @echo "${OK_COLOR}Done!${NO_COLOR}"

########################################
#                UTIL                  #
########################################

xdebug-enable: ## To enable xdebug
    @echo "zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20160303/xdebug.so" > php/xdebug.ini
    @docker-compose restart php

xdebug-disable: ## To disable xdebug
    @echo "" > php/xdebug.ini
    @docker-compose restart php

cs-fixer: ## Fix CS
    @docker-compose exec php php bin/php-cs-fixer fix ./src --rules='{"@Symfony": true,"@Symfony:risky":true,"array_syntax":{"syntax":"short"},"protected_to_private":false}' --allow-risky=yes --verbose --show-progress=estimating --using-cache=no

cs-fixer-dry-run: ## Fix CS (Dry run)
    @docker-compose exec php php bin/php-cs-fixer fix ./src --rules='{"@Symfony": true,"@Symfony:risky":true,"array_syntax":{"syntax":"short"},"protected_to_private":false}' --allow-risky=yes --verbose --show-progress=estimating --using-cache=no --dry-run

########################################
#                TESTS                 #
########################################

test-unit: ## Test unit
    @docker-compose exec php php bin/phpunit --configuration infra/app/tests/phpunit.xml --testsuite unit

test-functional: ## Test functional
    @docker-compose exec php php bin/phpunit --configuration infra/app/tests/phpunit.xml --testsuite functional

profile="chrome"
tags="project"
# feature="--skip-isolators=database,cache,import_export"
# make test-behat
# make test-behat tags=project1
# make test-behat profile=chrome
# make test-behat feature="--skip-isolators=database,cache,import_export"
# make test-behat feature="--skip-isolators=database,cache,import_export src/Project/Bundle/ProductBundle/Tests/Behat/Features/product.feature"
test-behat: ## Test behat
    @docker-compose -f selenium/docker-compose.yml up -d selenium-hub ${profile}
    @docker-compose exec php php -dmemory_limit=-1 bin/behat --tags=${tags} --profile=${profile} --config=infra/app/tests/behat.yml ${feature}

i = 1
# make test-behat-isolation
# make test-behat-isolation tags=project1
# make test-behat-isolation profile=chrome
# make test-behat-isolation feature="--skip-isolators=database,cache,import_export"
# make test-behat-isolation feature="src/Project/Bundle/ProductBundle/Tests/Behat/Features/product.feature"
# make test-behat-isolation i=2
# make test-behat-isolation i=3
test-behat-isolation: ## Test behat with isolation
    @docker-compose -f selenium/docker-compose.yml up -d selenium-hub ${profile}
    @echo "${WARN_COLOR}Cloning database...${NO_COLOR}"
    @docker-compose exec database /bin/bash /clone.sh 'clone' ${i}
    @echo "${WARN_COLOR}Cloning source....${NO_COLOR}"
    @docker-compose exec --user=root php /bin/bash /var/www/project/infra/php/clone.sh 'clone' /var/www/project ${i}
    @echo "${WARN_COLOR}Running tests...${NO_COLOR}"
    @-docker-compose exec php /bin/bash -c "cd /var/www/project${i} && php -dmemory_limit=-1 bin/behat --tags='${tags}' --profile=${profile} --config=infra/app/tests/behat.yml ${feature}"
    @echo "${WARN_COLOR}Removing database...${NO_COLOR}"
    @docker-compose exec database /bin/bash /clone.sh 'drop' ${i}
    @echo "${WARN_COLOR}Removing source...${NO_COLOR}"
    @docker-compose exec php /bin/bash /var/www/project/infra/php/clone.sh 'drop' /var/www/project ${i}
    @echo "${OK_COLOR}Done!${NO_COLOR}"

########################################
#                PRODUCTION            #
########################################

remote_host=production.host
remote_user=user
db_host=db.host
db_user=db_user
db_name=db_name

define product-db-dump-server-cmd
    rm -rf /tmp/pg_dump /tmp/pg_dump.tar.gz \
        && mkdir /tmp/pg_dump \
        && pg_dump -U ${db_user} -h ${db_host} -j ${parallel} -Fd -f /tmp/pg_dump ${db_name} \
        && cd /tmp \
        && tar -czf pg_dump.tar.gz pg_dump/*
endef

define product-db-dump-cmd
    echo "Dumping database on server..." \
    && ssh \
        -o "ExitOnForwardFailure=yes" \
        -o "StrictHostKeyChecking=no" \
        -o "UserKnownHostsFile=/dev/null" \
        ${remote_user}@${remote_host} "${product-db-dump-server-cmd}"\
    && echo "Downloading..." \
    && scp \
        -o "StrictHostKeyChecking=no" \
        -o "UserKnownHostsFile=/dev/null" \
        ${remote_user}@${remote_host}:/tmp/pg_dump.tar.gz infra/db/pg_dump.tar.gz \
    && echo "Removing server dumped db files..." \
    && ssh \
       -o "ExitOnForwardFailure=yes" \
       -o "StrictHostKeyChecking=no" \
       -o "UserKnownHostsFile=/dev/null" \
       ${remote_user}@${remote_host} "rm -rf /tmp/pg_dump /tmp/pg_dump.tar.gz" \
    && TIMESTAMP=$$(date +"%Y-%m-%d-%H-%M") && cp infra/db/pg_dump.tar.gz infra/db/db-product-$${TIMESTAMP}.tar.gz \
    && echo "Done!"
endef

product-db-dump: ## To dump database from production
    @docker-compose exec php /bin/bash -c '${product-db-dump-cmd}'

product-deploy: ## To deploy to production
    @docker-compose exec php dep deploy awsprod