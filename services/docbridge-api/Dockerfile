FROM oven/bun:1-alpine AS base
WORKDIR /app

COPY package.json tsconfig.base.json bun.lock ./
COPY packages packages
COPY services services
COPY workers workers
COPY web web

RUN bun install --frozen-lockfile

EXPOSE 3003
ENV PORT=3003

CMD ["bun", "run", "services/docbridge-api/src/index.ts"]