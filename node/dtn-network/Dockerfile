# Use Alpine Linux with Node.js 18
FROM node:18-alpine

# Install necessary packages for building
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsup.config.ts ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/

# Build the application
RUN npm run build

# Create a non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose any necessary ports (if needed)
# EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production

# Default command
CMD ["node", "dist/index.js", "--help"] 