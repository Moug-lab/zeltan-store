# Use official Node.js image
FROM node:20-alpine

# Set production environment
ENV NODE_ENV=production

# Set working directory inside container
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ONLY production dependencies
RUN npm install --omit=dev

# Copy all backend files
COPY . .

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose backend port
EXPOSE 5000

# Start backend server
CMD ["node", "server.js"]