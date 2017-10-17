FROM bitwalker/alpine-elixir:latest

ENV TERM=xterm

RUN mkdir -p /opt/app \
    && chmod -R 777 /opt/app \
    && apk update \
    && apk --no-cache --update add \
      git make g++ wget curl inotify-tools nodejs nodejs-current-npm \
    && npm install npm -g --no-progress \
    && update-ca-certificates --fresh \
    && rm -rf /var/cache/apk/*

ENV PATH=./node_modules/.bin:$PATH \
    HOME=/opt/app

RUN mix local.hex --force \
    && mix local.rebar --force

WORKDIR /opt/app

ENV MIX_ENV=prod \
    REPLACE_OS_VARS=true

COPY . .

RUN mix do deps.get, compile \
    && cd apps/tanx_web/assets \
    && npm install \
    && ./node_modules/brunch/bin/brunch build -p \
    && cd .. \
    && mix phx.digest \
    && cd ../.. \
    && mix release --env=prod --verbose


FROM bitwalker/alpine-erlang:latest

EXPOSE 8080
ENV PORT=8080 MIX_ENV=prod REPLACE_OS_VARS=true SHELL=/bin/sh

COPY --from=0 /opt/app/_build/prod/rel/tanx .
RUN chown -R default .

USER default

ENTRYPOINT ["/opt/app/bin/tanx"]
CMD ["foreground"]
