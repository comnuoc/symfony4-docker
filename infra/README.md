Symfony 4 Application
============

## Global prerequisites

The infrastructure is installed with [Docker](https://docs.docker.com/engine/installation/),
and [Docker Compose](https://docs.docker.com/compose/install/), so you have to
install these tools first.

`overlay2` storage driver is recommended
[Select storage driver](https://docs.docker.com/engine/userguide/storagedriver/overlayfs-driver/#configure-docker-with-the-overlay-or-overlay2-storage-driver)

**Make sure you have no local running services on ports 80, 1080, 9000 and 5432 before continuing with the installation process. (run `lsof -i :1080` to check it).**

## How it works?

The entry point is `infra/docker-compose-alpine.yml`, see the official documentation to handle it: https://docs.docker.com/compose/overview/.
This file describes the global infrastructure, ie all the services required to run properly the project.

A `Makefile` provides some shortcuts to help you. Just run `make` to see a help menu.

## Installation

Mac OS:
1. [Require make >= v4.0](https://stackoverflow.com/questions/43175529/updating-make-version-4-1-on-mac).
2. [Install docker-sync](https://github.com/EugenMayer/docker-sync).

Steps to execute from your host machine:

1. Create and start the containers:
    1. Linux: `make setup`.
    2. Mac OS: `make setup PHP_OS=alpine-mac`.
2. Edit file `./php/composer-auth.json` for [composer authentication](https://getcomposer.org/doc/articles/http-basic-authentication.md).
3. Install vendors: `make app-vendors-install`.
4. First installation or restore database:
    1. First installation: `make app-install`.    
    2. Restore database:    
        * Prepare database file: `./db/pg_dump.tar.gz`.        
        * Restore: `make db-restore`.
5. Edit your `/etc/hosts` file and add: `127.0.0.1  project.local`.

That's it! ;) Let's go: 

* http://project.local
* http://project.local:1080        (MailCatcher UI).

### Local

4 containers are running:

1. `nginx`:   executes Nginx latest alpine.
2. `php`:       executes PHP-FPM 7.2 alpine.
3. `database`:  executes Postgres 10.3 alpine.
4. `smtp`:      executes SMTP.

If you want to backup the database, you need to run ``make db-dump``. If you want to restore it, you can then run ``make db-restore``.
Database path `./db/pg_dump.tar.gz`.

#### Troubeshooting

Mac OS:
1. If there is an issue with permission. Run `make fix-permission` then run `make infra-up`.

