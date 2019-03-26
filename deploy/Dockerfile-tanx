FROM tanx-builder-base
WORKDIR /opt/app
COPY . .
RUN mv /opt/base-app/_build _build \
    && mv /opt/base-app/deps deps \
    && mv /opt/base-app/apps/tanx_web/assets/node_modules apps/tanx_web/assets/node_modules \
    && mix compile \
    && cd apps/tanx_web/assets \
    && node_modules/webpack/bin/webpack.js --mode production \
    && cd .. \
    && mix phx.digest
RUN mix release --env=prod --verbose \
    && mv _build/prod/rel/tanx /opt/release \
    && mv /opt/release/bin/tanx /opt/release/bin/start_server

FROM tanx-runtime-base
ARG build_id=local
ENV PORT=8080 \
    MIX_ENV=prod \
    REPLACE_OS_VARS=true \
    TANX_BUILD_ID=${build_id}
WORKDIR /opt/app
COPY --from=0 /opt/release .
EXPOSE ${PORT}
CMD ["/opt/app/bin/start_server", "foreground"]
