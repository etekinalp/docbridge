FROM oven/bun:1-alpine AS base
WORKDIR /app

COPY package.json tsconfig.base.json bun.lock ./
COPY packages/shared packages/shared
COPY services/docbridge-api services/docbridge-api

RUN bun install --frozen-lockfile

EXPOSE 3003
ENV PORT=3003

CMD ["bun", "run", "services/docbridge-api/src/index.ts"]