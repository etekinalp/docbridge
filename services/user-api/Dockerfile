FROM oven/bun:1-alpine AS base
WORKDIR /app

COPY package.json tsconfig.base.json bun.lock ./
COPY packages/shared packages/shared
COPY services/user-api services/user-api

RUN bun install --frozen-lockfile

EXPOSE 3001
ENV PORT=3001

CMD ["bun", "run", "services/user-api/src/index.ts"]