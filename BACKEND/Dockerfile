# Backend E-VIDENTE → Supabase Postgres
# Build: docker build -t e-vidente-api .
# Run:   docker run --env-file .env.production -p 3000:3000 e-vidente-api

FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
COPY migrations ./migrations
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${BACKEND_PORT:-3000}/health/ready || exit 1
CMD ["npm", "run", "start:prod"]
