FROM oven/bun:latest

WORKDIR /app

COPY package.json .

RUN bun install
RUN bun install @elysiajs/cors

COPY . .

EXPOSE 8080

CMD ["bun", "src/index.ts"]