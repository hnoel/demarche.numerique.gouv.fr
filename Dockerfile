#---------------------------------------------------------------------------------
# Build node_modules dependencies using Bun image
#---------------------------------------------------------------------------------
FROM oven/bun:1 AS bun
WORKDIR /app
COPY package.json bun.lock* ./
COPY patches ./patches/
RUN bun install --frozen-lockfile --production

#--------------------------------------------------
# Builder
# Intermediate container to bundle all gems
# Building gems requires dev librairies we don't need in production container
#--------------------------------------------------
FROM ruby:3.4.5-slim AS base

# Avoid warnings by switching to noninteractive
ARG DEBIAN_FRONTEND=noninteractive

FROM base AS builder

RUN apt-get update && \
    apt-get install -y curl build-essential git libpq-dev libicu-dev zlib1g-dev libyaml-dev gnupg zip nodejs && \
    (curl -sL "https://deb.nodesource.com/setup_22.x" | bash -) && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV INSTALL_PATH=/app
RUN mkdir -p ${INSTALL_PATH}
WORKDIR ${INSTALL_PATH}
COPY Gemfile Gemfile.lock ./

# sassc https://github.com/sass/sassc-ruby/issues/146#issuecomment-608489863
RUN bundle config specific_platform x86_64-linux \
  && bundle config build.sassc --disable-march-tune-native \
    && bundle config deployment true \
       && bundle config without "development test" \
         && bundle install

#---------------------------------------------------------------------------------
#  App/Worker container
#---------------------------------------------------------------------------------
FROM base AS preprod
ENV APP_PATH /app

#----- minimum set of packages
RUN apt-get update && apt-get install -y curl git postgresql-client libicu76 poppler-utils imagemagick ghostscript gnupg zip
RUN (curl -sL "https://deb.nodesource.com/setup_22.x" | bash -) \
      && apt-get install -y nodejs

RUN adduser --disabled-password --home ${APP_PATH} userapp
USER userapp
WORKDIR ${APP_PATH}

ADD image_magick_policy.xml /etc/ImageMagick-6/policy.xml

FROM preprod AS prod
#----- Building js dependencies (node_modules)
RUN (curl -fsSL https://bun.sh/install | bash)
COPY package.json bun.lock* ./
COPY patches ./patches/
COPY --chown=userapp:userapp --from=bun /app/node_modules ${APP_PATH}/node_modules
RUN .bun/bin/bun install --production

#----- Bundle gems: copy from builder container the dependency gems
#cf https://imagetragick.com/
COPY --chown=userapp:userapp --from=builder /app ${APP_PATH}/

RUN bundle config specific_platform x86_64-linux \
      && bundle config build.sassc --disable-march-tune-native \
        && bundle config deployment true \
          && bundle config without "development test" \
            && bundle install

COPY --chown=userapp:userapp . ${APP_PATH}
RUN chmod a+x $APP_PATH/app/lib/*.sh

#----- Precompile assets
RUN RAILS_ENV=production NODE_OPTIONS=--max-old-space-size=4000 bundle exec rails assets:precompile --trace

# add .dockerignore instead of rm or be more selective during building
RUN rm -rf CONTRIBUTING.fr.md  CONTRIBUTING.md  README.fr.md  README.md  SECURITY.md LICENSE.txt image_magick_policy.xml doc codecov.yml bors.toml Guardfile Procfile.dev Dockerfile eslint.config.ts bun.lock .bun .ruby-version .gpg_authorized_keys .github .rspec .gitignore .env.test vitest.config.ts .simplecov .haml-lint.yml .gitattributes .editorconfig .rubocop.yml node_modules .erdconfig vite.config.ts log package.json v postcss.config.js magidoc.mjs tsconfig.json publiccode.yml .env

#---------------------------------------------------------------------------------
#  App/Worker container-slim
#---------------------------------------------------------------------------------
FROM preprod AS prod-slim
# copy bundle config
COPY --chown=userapp:userapp --from=prod /usr/local/bundle/config /usr/local/bundle/config
# copy 'slim' app folder 
COPY --chown=userapp:userapp --from=prod /app ${APP_PATH}/

EXPOSE 3000
ENTRYPOINT ["/app/app/lib/docker-entry-point.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
