FROM containers.cisco.com/sto-ccc-cloud9/hardened_alpine:latest
# Overwrite inherited expiration from cloud9's image with blank value
LABEL quay.expires-after=

ARG ROOT_CERTIFICATE_FILENAME=V3_RootBundleSigningCertificate.zip
ARG ROOT_CERTIFICATE_URL=https://cswiki.cisco.com/download/attachments/46400484/${ROOT_CERTIFICATE_FILENAME}?api=v2
ARG CERTIFICATE_BUNDLE_URL=https://www.cisco.com/security/pki/trs/ios_core.p7b

ARG BUILD_VERSION=20.15.0

ENV NODE_VERSION=$BUILD_VERSION

COPY openssl.conf /tmp/openssl.conf
RUN apk update \
  && apk add --no-cache --virtual .build-deps curl openssl \
  # Create root bundle signing certificate so that cisco p7b files can be converted to pem format
  && mkdir /temp_cert \
  && cd /temp_cert \
  && curl -fsSLO ${ROOT_CERTIFICATE_URL} \
  && unzip ${ROOT_CERTIFICATE_FILENAME} \
  && OPENSSL_CONF=/tmp/openssl.conf curl -fsSLO ${CERTIFICATE_BUNDLE_URL} \
  && rm -f /tmp/openssl.conf \
  && openssl cms -verify -nointern -noverify \
    -inform DER -in /temp_cert/ios_core.p7b \
    -outform DER -out /temp_cert/bundleBodyVerified.p7b \
    -certfile /temp_cert/RootBundleSigningCertificate.cer \
  && openssl pkcs7 \
    -inform DER -print_certs \
    -outform PEM < /temp_cert/bundleBodyVerified.p7b \
    | grep -v 'subject=' | grep -v 'issuer=' | sed '/^$/d' > cert.pem \
  && echo '#if defined(NODE_WANT_INTERNALS) && NODE_WANT_INTERNALS' > temp.h \
  && sed 's/^.*$/"&\\n"/g' cert.pem >> temp.h \
  && echo '#endif  // defined(NODE_WANT_INTERNALS) && NODE_WANT_INTERNALS' >> temp.h \
  && sed 's/"-----END CERTIFICATE-----\\n"/"-----END CERTIFICATE-----\\n",/g' temp.h > /temp_cert/node_root_certs.h \
  && apk del .build-deps \
  && cd .. \
  && addgroup -g 1000 node \
  && adduser -u 1000 -G node -s /bin/sh -D node \
  && apk add --no-cache \
      libstdc++ \
  && apk add --no-cache --virtual .build-deps-full \
      curl \
      binutils-gold \
      g++ \
      gcc \
      gnupg \
      libgcc \
      linux-headers \
      make \
      python3 \
  # use pre-existing gpg directory, see https://github.com/nodejs/docker-node/pull/1895#issuecomment-1550389150
  && export GNUPGHOME="$(mktemp -d)" \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && for key in \
      4ED778F539E3634C779C87C6D7062848A1AB005C \
      141F07595B7B3FFE74309A937405533BE57C7D57 \
      74F12602B6F1C4E913FAA37AD3A89613643B6201 \
      DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
      61FC681DFB92A079F1685E77973F295594EC4689 \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
      C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
      108F52B48DB57BB0CC439B2997B01419BD92F80A \
      A363A499291CBBC940DD62E41F10027AF002F8B0 \
      CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
  ; do \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && gpgconf --kill all \
  && rm -rf "$GNUPGHOME" \
  && grep "node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xf "node-v$NODE_VERSION.tar.xz" \
  && cd "node-v$NODE_VERSION" \
  && mv /temp_cert/node_root_certs.h src/node_root_certs.h \
  && mv /temp_cert/cert.pem /etc/ssl/cert.pem \
  && rm -rf /temp_cert \
  && ./configure \
  && make -j$(getconf _NPROCESSORS_ONLN) V= \
  && make install \
  && cd .. \
  && rm -Rf "node-v$NODE_VERSION" \
  && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && apk del .build-deps-full

COPY ["docker-entrypoint.sh", "/usr/local/bin/"]
ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD ["node"]
