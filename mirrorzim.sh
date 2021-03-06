#!/bin/bash
# vim: set ts=2 sw=2:

set -euo pipefail

# Download a zim file, unpack it, convert to website then push to local ipfs instance

usage() {
	echo "USAGE:"
	echo " $0 - download a zim file, unpack it, convert to website then push to local ipfs instance"
	echo ""
	echo "SYNOPSIS"
	echo " $0 --languagecode=<LANGUAGE_CODE> --wikitype=<WIKI_TYPE>"
	echo "    [--hostingdnsdomain=<HOSTING_DNS_DOMAIN>]"
	echo "    [--hostingipnshash=<HOSTING_IPNS_HASH>]"
	echo "    [--mainpageversion=<MAIN_PAGE_VERSION>]"
	echo ""
	echo "OPTIONS"
	echo ""
	echo "  -l, --languagecode       string - the language of the wikimedia property e.g. tr - turkish, en - english"
	echo "  -w, --wikitype           string - the type of the wikimedia property e.g. wikipedia, wikiquote"
	echo "  -d, --hostingdnsdomain   string - the DNS domain name the mirror will be hosted at e.g. tr.wikipedia-on-ipfs.org"
	echo "  -i, --hostingipnshash    string - the IPNS hash the mirror will be hosted at e.g. QmVH1VzGBydSfmNG7rmdDjAeBZ71UVeEahVbNpFQtwZK8W"
	echo "  -v, --mainpageversion    string - an override hack used on Turkish Wikipedia, it sets the main page version as there are issues with the Kiwix version id"

	exit 2
}


for i in "$@"
do
case $i in
    -l=*|--languagecode=*)
    LANGUAGE_CODE="${i#*=}"
    shift
    ;;
    -w=*|--wikitype=*)
    WIKI_TYPE="${i#*=}"
    shift
    ;;
    -d=*|--hostingdnsdomain=*)
    HOSTING_DNS_DOMAIN="${i#*=}"
    shift
    ;;
	-i=*|--hostingipnshash=*)
    HOSTING_IPNS_HASH="${i#*=}"
    shift
    ;;
	-v=*|--mainpageversion=*)
    MAIN_PAGE_VERSION="${i#*=}"
    shift
    ;;
    --default)
    DEFAULT=YES
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

if [ -z ${LANGUAGE_CODE+x} ]; then
	echo "Missing wiki language code e.g. tr - turkish, en - english"
	usage
fi

if [ -z ${WIKI_TYPE+x} ]; then
	echo "Missing wiki type e.g. wikipedia, wikiquote"
	usage
fi

if [ -z ${HOSTING_DNS_DOMAIN+x} ]; then
	HOSTING_DNS_DOMAIN=""
fi

if [ -z ${HOSTING_IPNS_HASH+x} ]; then
	HOSTING_IPNS_HASH=""
fi

if [ -z ${MAIN_PAGE_VERSION+x} ]; then
	MAIN_PAGE_VERSION=""
fi

printf "\nDownload the zim file...\n"
ZIM_FILE_SOURCE_URL="$(./tools/getzim.sh download $WIKI_TYPE $WIKI_TYPE $LANGUAGE_CODE all maxi latest | grep 'URL:' | cut -d' ' -f3)"
ZIM_FILE=$(echo $ZIM_FILE_SOURCE_URL | rev | cut -d'/' -f1 | rev)
TMP_DIRECTORY="./tmp/$(echo $ZIM_FILE | cut -d'.' -f1)"

printf "\nRemove tmp directory $TMP_DIRECTORY before run ..."
rm -rf $TMP_DIRECTORY

printf "\nUnpack the zim file into $TMP_DIRECTORY...\n"
ZIM_FILE_MAIN_PAGE=$(./extract_zim/extract_zim ./snapshots/$ZIM_FILE --out $TMP_DIRECTORY | grep 'Main page is' | cut -d' ' -f4)

# Resolve the main page as it is on wikipedia over http
MAIN_PAGE=$(./tools/find_main_page_name.sh "$LANGUAGE_CODE.$WIKI_TYPE.org")

printf "\nConvert the unpacked zim directory to a website\n"
node ./bin/run $TMP_DIRECTORY \
  --zimfilesourceurl=$ZIM_FILE_SOURCE_URL \
  --kiwixmainpage=$ZIM_FILE_MAIN_PAGE \
  --mainpage=$MAIN_PAGE \
  ${HOSTING_DNS_DOMAIN:+--hostingdnsdomain=$HOSTING_DNS_DOMAIN} \
  ${HOSTING_IPNS_HASH:+--hostingipnshash=$HOSTING_IPNS_HASH} \
  ${MAIN_PAGE_VERSION:+--mainpageversion=$MAIN_PAGE_VERSION}

printf "\nAdd the processed tmp directory to IPFS\n"
CID=$(ipfs add -r --cid-version 1 --offline $TMP_DIRECTORY | tail -n -1 | cut -d' ' -f2 )

printf "\nThe CID of $ZIM_FILE is:\n$CID\n"