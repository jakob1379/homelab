#!/bin/sh
set -eu

value="$(printenv KARAKEEP_OAUTH_WELLKNOWN_URL || true)"
if [ -n "$value" ]; then
  export "OAUTH_WELLKNOWN_URL=${value}"
fi

exec /init "$@"
