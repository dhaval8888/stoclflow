# ─── StockFlow API Dockerfile ──────────────────────────────────────────────
FROM node:20-alpine AS base

WORKDIR /app

# Install dependencies required for native builds if needed
RUN apk add --no-cache libc6-compat

# Copy package descriptors
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY server.js ./
COPY src ./src

# Create non-root user and assign ownership
RUN chown -R node:node /app
USER node

# Expose default API port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
