FROM oven/bun:1-alpine AS base
WORKDIR /app

COPY package.json tsconfig.base.json bun.lock ./
COPY packages/shared packages/shared
COPY services/platform-api services/platform-api

RUN bun install --frozen-lockfile

EXPOSE 3002
ENV PORT=3002

CMD ["bun", "run", "services/platform-api/src/index.ts"]