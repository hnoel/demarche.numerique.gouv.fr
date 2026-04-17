#---------------------------------------------------------------------------------
# Build node_modules dependencies using Bun image
#---------------------------------------------------------------------------------
FROM docker.io/oven/bun:1.3 AS bun
WORKDIR /app
COPY package.json bun.lock* ./
COPY patches ./patches/
RUN bun install --frozen-lockfile --production --minify

#--------------------------------------------------
# Builder
# Intermediate container to bundle all gems
# Building gems requires dev librairies we don't need in production container
#--------------------------------------------------
FROM docker.io/ruby:3.4.5-slim AS base

# Avoid warnings by switching to noninteractive
ARG DEBIAN_FRONTEND=noninteractive

FROM base AS builder

RUN /usr/bin/apt-get update && \
    /usr/bin/apt-get install --no-install-recommends -y curl build-essential git libpq-dev libicu-dev zlib1g-dev libyaml-dev gnupg zip && \
    (curl -sL "https://deb.nodesource.com/setup_22.x" | bash -) && \
    /usr/bin/apt-get install -y nodejs && \
    /usr/bin/apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV INSTALL_PATH=/app
RUN mkdir -p ${INSTALL_PATH}
WORKDIR ${INSTALL_PATH}
#COPY Gemfile Gemfile.lock ./
COPY Gemfile  ./

# sassc https://github.com/sass/sassc-ruby/issues/146#issuecomment-608489863
#RUN bundle config specific_platform x86_64-linux && \
RUN bundle config build.sassc --disable-march-tune-native && \
    bundle config deployment true && \
    bundle config without "development test" && \
    bundle install

#---------------------------------------------------------------------------------
#  App/Worker container
#---------------------------------------------------------------------------------
FROM base AS preprod
ENV APP_PATH="/app"
ENV PATH="${PATH}:${APP_PATH}/.bun/bin"

#----- minimum set of packages
RUN /usr/bin/apt-get update && \
    /usr/bin/apt-get install --no-install-recommends -y curl git postgresql-client libicu76 poppler-utils imagemagick ghostscript gnupg unzip && \
    (curl -sL "https://deb.nodesource.com/setup_22.x" | bash -) && \
    /usr/bin/apt-get install -y nodejs && \
    /usr/bin/apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --home ${APP_PATH} userapp
USER userapp
WORKDIR ${APP_PATH}

ADD image_magick_policy.xml /etc/ImageMagick-6/policy.xml

FROM preprod AS prod
#----- Building js dependencies (node_modules)
#RUN (curl -fsSL https://bun.sh/install | bash) # Warning: install 'bun' in current user 'home' folder
COPY --chown=userapp:userapp --from=bun /usr/local/bin/bun /usr/local/bin/bun
COPY package.json bun.lock* ./
COPY patches ./patches/
COPY --chown=userapp:userapp --from=bun /app/node_modules ${APP_PATH}/node_modules
RUN /usr/local/bin/bun install --production

#----- Bundle gems: copy from builder container the dependency gems
#cf https://imagetragick.com/
COPY --chown=userapp:userapp --from=builder /app ${APP_PATH}/

RUN bundle config specific_platform x86_64-linux && \
    bundle config build.sassc --disable-march-tune-native && \
    bundle config deployment true && \
    bundle config without "development test" && \
    bundle install

COPY --chown=userapp:userapp . ${APP_PATH}
RUN chmod a+x $APP_PATH/app/lib/*.sh

ENV \
    ACTIVE_STORAGE_SERVICE="s3" \
    AGENT_CONNECT_ENABLED="" \
    AGENT_CONNECT_ID="" \
    AGENT_CONNECT_SECRET="" \
    AGENT_CONNECT_BASE_URL="" \
    AGENT_CONNECT_JWKS="" \
    AGENT_CONNECT_REDIRECT="" \
    API_ADRESSE_URL="" \
    API_COJO_URL="" \
    API_CPS_AUTH="" \
    API_CPS_CLIENT_ID="" \
    API_CPS_CLIENT_SECRET="" \
    API_CPS_PASSWORD="" \
    API_CPS_URL="" \
    API_CPS_USERNAME="" \
    API_EDUCATION_URL="" \
    API_ENTREPRISE_DEFAULT_SIRET="" \
    API_ENTREPRISE_KEY="" \
    API_ISPF_AUTH_URL="" \
    API_ISPF_URL="" \
    API_ISPF_PASSWORD="" \
    API_ISPF_USER="" \
    APPLICATION_BASE_URL="" \
    APPLICATION_NAME="" \
    APP_HOST="" \
    APP_NAME="" \
    AR_ENCRYPTION_KEY_DERIVATION_SALT="" \
    AR_ENCRYPTION_PRIMARY_KEY="" \
    BASIC_AUTH_ENABLED="disabled" \
    BASIC_AUTH_PASSWORD="" \
    BASIC_AUTH_USERNAME="" \
    CARRIERWAVE_CACHE_DIR="" \
    CLAMAV_ENABLED="disabled" \
    COJO_JWT_RSA_PRIVATE_KEY="" \
    CRISP_CLIENT_KEY="" \
    CRISP_ENABLED="" \
    DB_DATABASE="tps" \
    DB_HOST="postgres" \
    DB_PASSWORD="tps_development" \
    DB_POOL="" \
    DB_USERNAME="tps_development" \
    DB_PORT="5432" \
    UNIVERSIGN_API_URL="" \
    UNIVERSIGN_USERPWD="" \
    API_GEO_DEGRADED_MODE="" \
    API_GEO_URL="" \
    DEMANDE_INSCRIPTION_ADMIN_PAGE_URL="" \
    DOLIST_BALANCING_VALUE="" \
    DOLIST_USERNAME="" \
    DOLIST_PASSWORD="" \
    DOLIST_ACCOUNT_ID="" \
    DOLIST_API_KEY="" \
    DOC_URL="" \
    DS_PROXY_URL="" \
    ENCRYPTION_SERVICE_SALT="" \
    FACEBOOK_CLIENT_ID="" \
    FACEBOOK_CLIENT_SECRET="" \
    FAVICON_16PX_SRC="" \
    FAVICON_32PX_SRC="" \
    FAVICON_96PX_SRC="" \
    FC_PARTICULIER_BASE_URL="" \
    FC_PARTICULIER_ID="" \
    FC_PARTICULIER_SECRET="" \
    FOG_DIRECTORY="" \
    FOG_ENABLED="" \
    FOG_OPENSTACK_API_KEY="" \
    FOG_OPENSTACK_AUTH_URL="" \
    FOG_OPENSTACK_IDENTITY_API_VERSION="" \
    FOG_OPENSTACK_REGION="" \
    FOG_OPENSTACK_TENANT="" \
    FOG_OPENSTACK_URL="" \
    FOG_OPENSTACK_USERNAME="" \
    GITHUB_CLIENT_ID="" \
    GITHUB_CLIENT_SECRET="" \
    GOOGLE_CLIENT_ID="" \
    GOOGLE_CLIENT_SECRET="" \
    HELPSCOUT_CLIENT_ID="" \
    HELPSCOUT_CLIENT_SECRET="" \
    HELPSCOUT_MAILBOX_ID="" \
    HELPSCOUT_WEBHOOK_SECRET="" \
    INVISIBLE_CAPTCHA_SECRET="" \
    LEGIT_ADMIN_DOMAINS="" \
    LOGRAGE_ENABLED="" \
    LOGRAGE_SOURCE="" \
    MAILCATCHER_ENABLED="" \
    MAILCATCHER_HOST="" \
    MAILCATCHER_PORT="" \
    MAILER_LOGO_SRC="" \
    MAILJET_API_KEY="" \
    MAILJET_SECRET_KEY="" \
    MAILTRAP_ENABLED="" \
    MAILTRAP_PASSWORD="" \
    MAILTRAP_USERNAME="" \
    MATOMO_ENABLED="" \
    MATOMO_COOKIE_DOMAIN="" \
    MATOMO_DOMAIN="" \
    MATOMO_HOST="" \
    MATOMO_ID="" \
    MATOMO_IFRAME_URL="" \
    MICROSOFT_CLIENT_ID="" \
    MICROSOFT_CLIENT_SECRET="" \
    OTP_SECRET_KEY="" \
    PIPEDRIVE_KEY="" \
    PROCEDURE_DEFAULT_LOGO_SRC="" \
    RAILS_ENV="production" \
    RAILS_LOG_TO_STDOUT="" \
    RAILS_SERVE_STATIC_FILES="" \
    RUBY_YJIT_ENABLE="" \
    SAML_IDP_ENABLED="" \
    SAML_IDP_CERTIFICATE="" \
    SAML_IDP_SECRET_KEY="" \
    SECRET_KEY_BASE="TO_FIX" \
    S3_ENDPOINT=" " \
    S3_BUCKET=" " \
    S3_ACCESS_KEY="" \
    S3_SECRET_KEY="" \
    S3_REGION=" " \
    SENDINBLUE_API_V3_KEY="" \
    SENDINBLUE_BALANCING_VALUE="" \
    SENDINBLUE_CLIENT_KEY="" \
    SENDINBLUE_LOGIN_URL="" \
    SENDINBLUE_SMTP_KEY="" \
    SENDINBLUE_USER_NAME="" \
    SENTRY_CURRENT_ENV="" \
    SENTRY_DSN_JS="" \
    SENTRY_DSN_RAILS="" \
    SENTRY_ENABLED="" \
    SIGNING_KEY="" \
    SIPF_CLIENT_BASE_URL="" \
    SIPF_CLIENT_ID="" \
    SIPF_CLIENT_SECRET="" \
    SKYLIGHT_AUTHENTICATION_KEY="" \
    SKYLIGHT_DISABLE_AGENT="" \
    SOURCE="" \
    STRICT_EMAIL_VALIDATION_STARTS_ON="" \
    TATOU_BASE_URL="" \
    TATOU_CLIENT_ID="" \
    TATOU_CLIENT_SECRET="" \
    TRUSTED_NETWORKS="" \
    CERTIGNA_USERPWD="" \
    WATERMARK_FILE="" \
    WEASYPRINT_URL="" \
    YAHOO_CLIENT_ID="" \
    YAHOO_CLIENT_SECRET=""
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

# Runtime user compatibility for both OpenShift and Kubernetes
USER root
RUN chgrp -R 0 ${APP_PATH}/ && \
    chmod -R g=u ${APP_PATH}/
USER userapp

EXPOSE 3000
ENTRYPOINT ["/app/app/lib/docker-entry-point.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
