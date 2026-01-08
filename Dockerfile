ARG APP_PATH=/opt/outline
ARG BASE_IMAGE=outlinewiki/outline-base
FROM ${BASE_IMAGE} AS base

ARG APP_PATH
WORKDIR $APP_PATH

# Optimize node_modules in base stage before copying
RUN find ./node_modules -name "*.md" -delete && \
    find ./node_modules -name "*.ts" -not -path "*/dist/*" -not -path "*/build/*" -delete && \
    find ./node_modules -name "*.map" -delete && \
    find ./node_modules -type f -name "LICENSE*" -delete && \
    find ./node_modules -type f -name "CHANGELOG*" -delete && \
    find ./node_modules -type f -name "README*" -delete && \
    find ./node_modules -name "*.test.js" -delete && \
    find ./node_modules -name "*.spec.js" -delete && \
    rm -rf ./node_modules/*/test ./node_modules/*/tests ./node_modules/*/.github && \
    rm -rf ./node_modules/*/docs ./node_modules/*/examples ./node_modules/*/coverage

# ---
FROM node:22.21.0-slim AS runner

LABEL org.opencontainers.image.source="https://github.com/outline/outline"

ARG APP_PATH
WORKDIR $APP_PATH
ENV NODE_ENV=production

# Create a non-root user compatible with Debian and BusyBox based images
RUN addgroup --gid 1001 nodejs && \
    adduser --uid 1001 --ingroup nodejs nodejs && \
    mkdir -p /var/lib/outline && \
    chown -R nodejs:nodejs /var/lib/outline && \
    chown -R nodejs:nodejs $APP_PATH

COPY --from=base --chown=nodejs:nodejs $APP_PATH/build ./build
COPY --from=base --chown=nodejs:nodejs $APP_PATH/server ./server
COPY --from=base --chown=nodejs:nodejs $APP_PATH/public ./public
COPY --from=base --chown=nodejs:nodejs $APP_PATH/.sequelizerc ./.sequelizerc
COPY --from=base --chown=nodejs:nodejs $APP_PATH/package.json ./package.json
COPY --from=base --chown=nodejs:nodejs $APP_PATH/node_modules ./node_modules

# Install wget to healthcheck the server
RUN  apt-get update \
    && apt-get install -y wget \
    && rm -rf /var/lib/apt/lists/*

ENV FILE_STORAGE_LOCAL_ROOT_DIR=/var/lib/outline/data
RUN mkdir -p "$FILE_STORAGE_LOCAL_ROOT_DIR" && \
    chown -R nodejs:nodejs "$FILE_STORAGE_LOCAL_ROOT_DIR" && \
    chmod 1777 "$FILE_STORAGE_LOCAL_ROOT_DIR"

VOLUME /var/lib/outline/data

USER nodejs

HEALTHCHECK --interval=1m CMD wget -qO- "http://localhost:${PORT:-3000}/_health" | grep -q "OK" || exit 1

EXPOSE 3000
CMD ["node", "build/server/index.js"]
