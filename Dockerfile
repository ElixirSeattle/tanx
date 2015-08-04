FROM trenpixster/elixir

RUN mkdir /nodejs && curl https://nodejs.org/dist/v0.12.7/node-v0.12.7-linux-x64.tar.gz | tar xvzf - -C /nodejs --strip-components=1

ENV PATH $PATH:/nodejs/bin:/elixir/bin
ENV HOME /tanx
ENV MIX_ENV prod
WORKDIR ${HOME}

COPY . ${HOME}

RUN /elixir/bin/mix local.hex --force && \
    /elixir/bin/mix local.rebar --force && \
    /elixir/bin/mix deps.get && \
    /nodejs/bin/npm install && \
    /elixir/bin/mix compile && \
    ./node_modules/brunch/bin/brunch build --production && \
    /elixir/bin/mix phoenix.digest

EXPOSE 8080
ENTRYPOINT /elixir/bin/mix phoenix.server
