FROM elixir:alpine
WORKDIR /opt/base-app
COPY . .
ENV MIX_ENV=prod \
    REPLACE_OS_VARS=true \
    TERM=xterm
RUN apk update \
    && apk --no-cache --update add build-base nodejs nodejs-npm python2 git \
    && mix local.rebar --force \
    && mix local.hex --force \
    && cd /opt/base-app \
    && mix do deps.get, deps.compile \
    && cd apps/tanx_web/assets/ \
    && npm install
