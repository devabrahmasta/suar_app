# --- Stage 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests
COPY package*.json ./

# Install all dependencies (including devDependencies)
RUN npm ci

# Copy source code and build the NestJS app
COPY . .
RUN npm run build

# --- Stage 2: Production Run ---
FROM node:20-alpine AS runner

WORKDIR /app

# Copy dependency manifests
COPY package*.json ./

# Install only production dependencies to keep the image slim
RUN npm ci --omit=dev

# Copy compiled JavaScript from build stage
COPY --from=builder /app/dist ./dist

# Hugging Face Spaces maps traffic to port 7860 by default
ENV PORT=7860
EXPOSE 7860

CMD ["node", "dist/main"]
