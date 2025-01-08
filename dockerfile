FROM alpine:latest

# Set default PUID and PGID
ARG PUID=1000
ARG PGID=1000

# Install required tools
RUN apk add --no-cache curl jq tzdata

# Set the timezone
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone
# Install necessary packages

# Create a non-root user and group using the PUID and PGID
RUN addgroup -g ${PGID} appgroup && \
    adduser -u ${PUID} -G appgroup -S appuser

# Copy the script into the container
COPY set_port.sh /usr/local/bin/set_port.sh

# Change ownership of the script to the non-root user and make it executable
RUN chown appuser:appgroup /usr/local/bin/set_port.sh && \
    chmod +x /usr/local/bin/set_port.sh

# Switch to the non-root user
USER appuser

# Run the script by default when the container starts
CMD ["/bin/sh", "/usr/local/bin/set_port.sh"]