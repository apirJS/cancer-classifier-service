FROM oven/bun:latest

COPY package.json .

RUN bun install
RUN bun install @elysiajs/cors

COPY . .

EXPOSE 8080

CMD ["node", "src/index.ts"]