#!/usr/bin/env bash

# essentially just a wrapper around:
# https://github.com/GEANT/CAT/blob/master/tutorials/UserAPI.md

info() { >&2 echo "$@"; }
warn() { >&2 echo "warning:" "$@"; }
error() { >&2 echo "error:" "$@"; }

select_option() (
  set -o pipefail
  FZF_DEFAULT_COMMAND=false fzf --no-multi --no-sort |
    sed -e 's/^.*(// ; s/)$//'
)

# DISCOVERY_ENDPOINT='https://discovery.eduroam.app/v1/discovery.json'
# discovery_json=$(curl "$DISCOVERY_ENDPOINT" | gzip -d)

# discovery_version=$(<<<"$discovery_json" jq -r .version)
# if [ "$discovery_version" != "1" ]; then
#   warn "the discovery api (at '$DISCOVERY_ENDPOINT') returned"
# fi

CAT_EDUROAM_URL='https://cat.eduroam.org'
USER_API_ENDPOINT=$CAT_EDUROAM_URL'/user/API.php'
queryUserAPI() {
  local url key
  url="$USER_API_ENDPOINT?"
  key=""
  for arg in "${defaultUserAPIArgs[@]}" action "$@"; do
    if [ -n "$key" ]; then
      url+="&$key=$arg"
      key=""
    else
      key=$arg
    fi
  done

  local curlArgs
  curlArgs=(
    --fail-with-body
    --no-progress-meter
    "$url"
  )

  # carriage return so that it get erased after the fetching
  >&2 printf '%s\r' "fetching response..."
  local response
  response=$(curl "${curlArgs[@]}") || {
    test -n "$response" && error "$response"
    error "failed to get a response from '$url'"
    return 1
  }

  local status data
  status=$(<<<"$response" jq -r .status)
  data=$(<<<"$response" jq -r .data)

  if [ "$status" != 1 ]; then
    if [ -n "$data" ]; then
      error "$data"
    else
      echo "$response"
    fi
    error "API failed with status '$status': '$url'"
    return 1
  fi

  printf %s "$data"
}

defaultUserAPIArgs=( api_version 2 )

locale=${LANGUAGE-}
test -z "$locale" && locale=${LC_ALL-}
test -z "$locale" && locale=${LC_MESSAGES-}
test -z "$locale" && locale=${LANG-}
test -z "$locale" && locale=en

languages=$(queryUserAPI listLanguages) || exit 1
sorted_str_languages=$(<<<"$languages" jq -r \
  --arg locale "$locale" \
  '
    def get_normal(s): s | split(".") | first;
    def get_lang_only(s): s | split("_") | first;
    reduce (
      map(select(get_lang_only(.locale) == get_lang_only($locale))),
      map(select(get_normal(.locale) == get_normal($locale))),
      map(select(.locale == $locale))
    ) as $to_top (.;
      $to_top + (. - $to_top)
    ) |
    .[] | "\(.display) (\(.lang))"
  '
)
lang=$(<<<"$sorted_str_languages" select_option) || {
  error "no language selection, exiting..."
  exit 1
}
defaultUserAPIArgs+=( lang "$lang" )

countries=$(queryUserAPI listCountries) || exit 1
country=$(<<<"$countries" jq -r '.[] | "\(.display) (\(.federation))"' | select_option) || {
  error "no country selection, exiting..."
  exit 1
}

identityProviders=$(queryUserAPI listIdentityProviders federation "$country") || exit 1
identityProvider=$(<<<"$identityProviders" jq -r '.[] | "\(.display) (\(.idp))"' | select_option) || {
  error "no organisation selection, exiting..."
  exit 1
}

profiles=$(queryUserAPI listProfiles idp "$identityProvider") || exit 1
profile=$(<<<"$profiles" jq -r '.[] | "\(.display) (\(.profile))"' | select_option) || {
  error "no profile selection, exiting..."
  exit 1
}

LINUX_DEVICE_ID=linux

attributes=$(queryUserAPI profileAttributes profile "$profile") || exit 1
<<<"$attributes" jq -r '
  [
    "Description: \(.description)",
    if has("local_email") or has("local_phone") or has("local_url") then
      "For help configuring eduroam, contact:",
      if has("local_email") then "email: \(.local_email)" else empty end,
      if has("local_phone") then "phone: \(.local_phone)" else empty end,
      if has("local_url")   then "web:   \(.local_url)"   else empty end
    else
      "No contacts provided."
    end
  ] | join("\n")
'
printf '\n'
message=$(<<<"$attributes" jq -r --arg device_id "$LINUX_DEVICE_ID" '
  [
    "Description: \(.description)",

    (.devices[] | select(.id == $device_id) | 
      "Profile has linux available :)",
      if (.eap_customtext | type) == "string" then .eap_customtext else empty end,
      if (.device_customtext | type) == "string" then .device_customtext else empty end,
      if (.message | type) == "string" then .message else empty end
    )
  ] | join("\n")
')
if [ -z "$message" ]; then
  error "Profile does not support linux :("
  exit 1
fi
printf '%s\n' "$message"

installer=$(queryUserAPI generateInstaller profile "$profile" device "$LINUX_DEVICE_ID") || exit 1
link=$(<<<"$installer" jq -r '.link')

read -rp "download installer from '$link' [y/n]? " reply
if [ "$reply" != "y" ]; then
  exit 1
fi

printf '\n'

tmpfile=$(mktemp --suffix=.py)
trap 'rm "$tmpfile"' EXIT

echo "downloading installer to '$tmpfile'..."
curl "$CAT_EDUROAM_URL/$link" --output "$tmpfile"

read -rp "run \`python3 '$tmpfile'\` [y/n]? " reply
if [ "$reply" != "y" ]; then
  exit 1
fi

# can't use exec bc the trap wouldn't be triggered
python3 "$tmpfile"
