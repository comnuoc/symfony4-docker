#!/bin/bash
set -e

COMMAND=${1:-clone}
SOURCE_PATH="$2"
CLONE_NO=${3:-1}
CLONE_PATH="${SOURCE_PATH}${CLONE_NO}"

rm -rf ${CLONE_PATH}/*

if [ "$COMMAND" = "clone" ]
then
    SCRIPT=$(readlink -f "$0")
    SCRIPT_PATH=$(dirname "$SCRIPT")
    COPY_PATH=("public/index.php")
    SYMLINK_PATH=("vendor" "bin")

    rsync -avzq --exclude-from=${SCRIPT_PATH}/clone_exclude.txt ${SOURCE_PATH}/ ${CLONE_PATH}/ \
        && for i in "${SYMLINK_PATH[@]}"; do ln -s ${SOURCE_PATH}/$i ${CLONE_PATH}/$i ; done \
        && ln -s ${SOURCE_PATH}/public/* ${CLONE_PATH}/public/ \
        && for i in "${COPY_PATH[@]}"; do rm -rf ${CLONE_PATH}/$i && cp ${SOURCE_PATH}/$i ${CLONE_PATH}/$i ; done \
        && chown -R www-data:www-data ${CLONE_PATH}
fi