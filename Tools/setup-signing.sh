#!/bin/sh
# 로그인 키체인에 자체 서명 코드 서명 인증서 "HangyeolIME Local Signing"을 만든다.
# 이미 있으면 아무것도 하지 않는다. (Signing.xcconfig 참고)
#
# 개인 키는 codesign 만 쓸 수 있게 접근을 제한한다(-T /usr/bin/codesign).
# 다른 앱이 이 키로 서명해 HangyeolIME의 손쉬운 사용 권한에 편승하지 못하게 하려는 것이다.
set -e
NAME="HangyeolIME Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KEYCHAIN" | grep -q "\"$NAME\""; then
  echo "서명 인증서 있음: $NAME"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = HangyeolIME Local Signing
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

PASS=$(openssl rand -hex 16)
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
# OpenSSL 3의 기본 암호화(AES·PBKDF2)는 macOS security가 읽지 못한다("MAC verification failed").
# LibreSSL·OpenSSL 3 모두 지원하는 옛 방식으로 묶는다.
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
  -out "$TMP/id.p12" -passout "pass:$PASS"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "서명 인증서 만듦: $NAME (10년 유효)"
echo "처음 이 인증서로 서명한 빌드는 손쉬운 사용 권한을 한 번 다시 허용해야 합니다."
