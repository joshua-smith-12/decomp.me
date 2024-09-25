#!/bin/bash

DB_HOST=${DATABASE_HOST:-postgres}
DB_PORT=${DATABASE_PORT:-5432}

BE_HOST=${BACKEND_HOST:-0.0.0.0}
BE_PORT=${BACKEND_PORT:-8000}

for reg in /backend/wine/*.reg; do
  echo "Importing registry file $reg..."
  regedit $reg
done

if [ "${ENABLE_MUGEN_SUPPORT}" = "YES" ]; then
  mkdir -p /backend/compilers/mugen/scratch
  git clone https://github.com/MugenDecomp/nrasm.git
  cd nrasm
  ./autogen.sh
  ./configure
  make
  cp nasm /backend/compilers/mugen/nasm
  cd ..
  rm -rf nrasm
fi
if [ "${ENABLE_MUGEN_SUPPORT}" = "YES" ]; then
  git clone https://github.com/mstorsjo/msvc-wine.git
  ./msvc-wine/vsdownload.py --msvc-version=17.11  --accept-license --dest /backend/compilers/mugen/msvc
  TMP=/backend/compilers/mugen/scratch ./msvc-wine/install.sh /backend/compilers/mugen/msvc
  rm -rf msvc-wine
fi

poetry config virtualenvs.path /backend/virtualenvs

poetry install

poetry run /backend/compilers/download.py
poetry run /backend/libraries/download.py

until nc -z ${DB_HOST} ${DB_PORT} > /dev/null; do
  #echo "Waiting for database to become available on ${DB_HOST}:${DB_PORT}..."
  sleep 1
done

poetry run /backend/manage.py migrate

poetry run /backend/manage.py runserver ${BE_HOST}:${BE_PORT}
