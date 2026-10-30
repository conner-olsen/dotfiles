#!/bin/zsh
# Signs a tool binary with the "local tools" certificate, created once in the login keychain.
# Its designated requirement is identifier + certificate, not the cdhash, so a rebuild keeps
# the binary's Privacy & Security grants. Usage: sign.sh <binary>
set -e
id="local tools"
if ! security find-certificate -c "$id" >/dev/null 2>&1; then
  d=$(mktemp -d)
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 36500 -subj "/CN=$id" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout $d/k -out $d/c 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey $d/k -in $d/c -passout pass:x -out $d/p
  security import $d/p -f pkcs12 -P x -T /usr/bin/codesign >/dev/null
  rm -r $d
fi
codesign -s "$id" -i local.${1:t} --signature-size 2048 --force $1  # default pads ~18 KB
