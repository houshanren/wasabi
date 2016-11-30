#!/usr/bin/env bash

# note: so that we can pick up the mvn env
. ~/.bashrc

usage () {
  echo "usage: `basename $0` [-n name] [-v version] [-p profile] [-h home] [-l log] [-t timestamp] [-d directory]"
  exit
}

fromPom() {
  mvn -f ../../../modules/$1/pom.xml -P $2 help:evaluate -Dexpression=$3 | sed -n -e '/^\[.*\]/ !{ p; }'
}

exitOnError() {
  echo "error cause: $1"
  exit 1
}

name=wasabi-spark-analytics
profile=development
timestamp=`date -u "+%Y%m%d%H%M%S"`
module=spark-analytics
dir=./target
wasabi_os_default=OSX

while getopts "n:v:p:i:h:l:t:" option; do
  case "$option" in
    n) name="$OPTARG";;
    v) version="$OPTARG";;
    p) profile="$OPTARG";;
    h) home="$OPTARG";;
    l) log="$OPTARG";;
    t) timestamp="$OPTARG";;
    d) dir="$OPTARG";;
    :) echo "Error: -$OPTARG requires an argument"
       usage
       exit 1
       ;;
    ?) echo "Error: unknown option -$OPTARG"
       usage
       exit 1
       ;;
  esac
done

version=${version:-`fromPom main ${profile} project.version`}
id=${name}-${version}-${profile}
home=${home:-/usr/local/$id}
log=${log:-/var/log/$id}
email=`fromPom main ${profile} application.email`

common="-s dir --force --debug --architecture noarch --name ${name}-${profile} --version ${version}\
  --iteration ${timestamp} --license APLv2.0 --vendor tbd --category application --provides ${name}-${profile}\
  --description ${name}-${version}-${profile} --url https://github.com/intuit/wasabi\
   --maintainer ${email}"

resources="bin=${home}/bin\
${id}-all.jar=${home}/lib/${id}-all.jar"

deb="-t deb"
rpm="-t rpm --rpm-os linux"
scripts="--before-install build/[PKG]/before-install.sh\
 --after-install build/[PKG]/after-install.sh\
 --before-remove build/[PKG]/before-remove.sh\
 --after-remove build/[PKG]/after-remove.sh"

for pkg in "deb" "rpm"; do
  fpm="${!pkg} $common `echo $scripts | sed -e "s/\[PKG\]/${pkg}/g"` $depends $resources"
  if [ "${WASABI_OS}" == "${WASABI_OSX}" ] || [ "${WASABI_OS}" == "${WASABI_LINUX}" ]; then
    docker run -it -v `pwd`:/build --rm liuedy/centos-fpm fpm ${fpm} || exitOnError "failed to build rpm: $module"
  else
    eval fpm ${fpm} || exitOnError "failed to build rpm: $module"
  fi
done