# ---- build stage ----
FROM docker.io/hexpm/elixir:1.16.3-erlang-26.2.5.21-debian-bookworm-20260824-slim AS build

# install build dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
    && mix local.rebar --force

# install deps first for layer caching
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod \
    && mix deps.compile

# copy app source
COPY lib ./lib
COPY priv ./priv

# compile and build a release
ENV MIX_ENV=prod
RUN mix compile --warnings-as-errors \
    && mix release --path /opt/release

# ---- runtime stage ----
FROM docker.io/debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PORT=8000 \
    MIX_ENV=prod \
    REPLACE_OS_VARS=true \
    RELEASE_COOKIE=stackbox

WORKDIR /app

# copy the built release
COPY --from=build /opt/release ./release

RUN groupadd -r app && useradd -r -g app app \
    && chown -R app:app /app

USER app

EXPOSE 8000

# Run DB migrations, then boot the Phoenix endpoint. `eval` runs one-off in
# the release's non-app context; `start` then launches the supervised app.
CMD ["sh", "-c", "./release/bin/stackbox eval \"Stackbox.Release.migrate()\" && exec ./release/bin/stackbox start"]
