FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4000
ENV NG_ALLOWED_HOSTS=localhost

COPY --from=build /app/dist/welcomepage ./dist/welcomepage

EXPOSE 4000
CMD ["node", "dist/welcomepage/server/server.mjs"]
