# syntax=docker/dockerfile:1

FROM node:20-slim AS base
ENV PLAYWRIGHT_SKIP_BROWSER_GC=1

# install dotenv-cli
RUN npm install -g dotenv-cli

# switch to a user that works for spaces
RUN userdel -r node
RUN useradd -m -u 1000 user
USER user

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

# add a .env.local if the user doesn't bind a volume to it
RUN touch /app/.env.local


RUN npm i --no-package-lock --no-save playwright@1.47.0
USER root
RUN apt-get update
RUN apt-get install gnupg curl -y
RUN npx playwright install --with-deps chromium
RUN chown -R 1000:1000 /home/user/.npm
USER user

COPY --chown=1000 .env /app/.env
COPY --chown=1000 entrypoint.sh /app/entrypoint.sh
COPY --chown=1000 gcp-*.json /app/
COPY --chown=1000 package.json /app/package.json
COPY --chown=1000 package-lock.json /app/package-lock.json

RUN chmod +x /app/entrypoint.sh


FROM node:20 AS builder

WORKDIR /app

COPY --link --chown=1000 package.json package-lock.json ./

ARG APP_BASE=/chat
ARG PUBLIC_APP_COLOR=blue
ENV BODY_SIZE_LIMIT=15728640

RUN --mount=type=cache,target=/app/.npm \
        npm set cache /app/.npm && \
        npm ci

COPY --link --chown=1000 . .

RUN git config --global --add safe.directory /app && \
    npm run build

# final image
# Changed base image to node:20-slim
FROM base AS final

WORKDIR /app

COPY --from=builder --chown=1000 /app/build /app/build
COPY --from=builder --chown=1000 /app/node_modules /app/node_modules

CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]