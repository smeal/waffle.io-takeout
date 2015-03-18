#!/bin/bash

blue='\033[0;34m'
red='\033[0;31m'
reset='\033[0m'

hash docker 2>/dev/null || { echo -e >&2 "${red}I require docker but it's not installed.  Aborting.${reset}"; exit 1; }

if [ ! $WAFFLE_AWS_ACCESS_KEY_ID ]
then
  echo -e "${red}You must supply an environment variable named $WAFFLE_AWS_ACCESS_KEY_ID set to your AWS access key.${reset}"
  exit 1
fi

if [ ! $WAFFLE_AWS_SECRET_ACCESS_KEY ]
then
  echo -e "${red}You must supply an environment variable named $WAFFLE_AWS_SECRET_ACCESS_KEY set to your AWS secret.${reset}"
  exit 1
fi

echo -e "\n${blue}Please login to quay.io${reset}"
docker login quay.io

mkdir -p waffleio-takeout

echo -e "\nPulling images from quay.io..."
docker pull quay.io/waffleio/hedwig
docker pull quay.io/waffleio/poxa
docker pull quay.io/waffleio/waffle.io-app
docker pull quay.io/waffleio/waffle.io-hooks
docker pull quay.io/waffleio/waffle.io-models
docker pull quay.io/waffleio/waffle.io-rally-integration

docker save --output="waffleio-takeout/hedwig.tar" quay.io/waffleio/hedwig
docker save --output="waffleio-takeout/poxa.tar" quay.io/waffleio/poxa
docker save --output="waffleio-takeout/waffle.io-app.tar" quay.io/waffleio/waffle.io-app
docker save --output="waffleio-takeout/waffle.io-hooks.tar" quay.io/waffleio/waffle.io-hooks
docker save --output="waffleio-takeout/waffle.io-models.tar" quay.io/waffleio/waffle.io-models
docker save --output="waffleio-takeout/waffle.io-rally-integration.tar" quay.io/waffleio/waffle.io-rally-integration

cp install.sh waffleio-takeout/
cp waffleio-env.list waffleio-takeout/

echo "Packaging files together"
zip -r waffleio-takeout.zip waffleio-takeout

rm -rf waffleio-takeout/

echo "Uploading to S3"
file=waffleio-takeout.zip
bucket="waffleio-takeout"
resource="/${bucket}/${file}"
contentType="application/zip"
dateValue=`TZ=utc date "+%a, %d %h %Y %T %z"`
stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
s3Key=$WAFFLE_AWS_ACCESS_KEY_ID
s3Secret=$WAFFLE_AWS_SECRET_ACCESS_KEY
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`

curl -k -X PUT -T "${file}" \
  -H "Host: ${bucket}.s3.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${s3Key}:${signature}" \
  https://${bucket}.s3.amazonaws.com/${file}

echo 'Finished'