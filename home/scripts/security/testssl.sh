# https://github.com/testssl/testssl.sh
if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  echo "Example: $0 example.com"
  exit 1
fi
docker run --rm -it ghcr.io/testssl/testssl.sh $1
