# syntax=docker/dockerfile:1
#
# Build context is this folder:
#   docker build -t contoso-fabric-web:dev app/src/web-next
#
# This is the CLEAN reference Dockerfile. It is here deliberately as the contrast case for
# api-dotnet/Dockerfile (CF-SUP-030, moving base tag) and worker-python/Dockerfile
# (CF-SUP-031, root user + no healthcheck): pinned minor base tag, multi-stage build,
# non-root runtime user, explicit healthcheck, and only the standalone output shipped.

FROM node:20.18-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20.18-bookworm-slim AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20.18-bookworm-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# `output: 'standalone'` in next.config.mjs emits a self-contained server bundle, so no
# node_modules copy is needed at runtime.
COPY --from=build /app/public ./public
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:3000/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

ENTRYPOINT ["node", "server.js"]
