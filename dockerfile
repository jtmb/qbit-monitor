FROM alpine:latest

# Set default PUID and PGID
ARG PUID=1000
ARG PGID=1000

# Install required tools
RUN apk add --no-cache curl jq tzdata grep bash

# Set the timezone
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone
# Install necessary packages

# Create a non-root user and group using the PUID and PGID
RUN mkdir /app /app/state && \
    addgroup -g ${PGID} appgroup && \
    adduser -u ${PUID} -G appgroup -S appuser

# Copy the script into the container
COPY main.sh /app/main.sh
COPY modules /app/modules

# Change ownership of the script to the non-root user and make it executable
RUN chown appuser:appgroup /app && \
    chown appuser:appgroup /app/state && \
    chown appuser:appgroup /app/main.sh && \
    chown -R appuser:appgroup /app/modules && \
    chmod +x /app/main.sh && \
    chmod -R +r /app/modules && \
    chmod -R +r /app/state

# Switch to the non-root user
USER appuser

# Set the working directory
WORKDIR /app

# Run the script by default when the container starts
CMD ["/bin/bash", "/app/main.sh"]