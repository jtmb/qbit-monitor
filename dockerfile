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
RUN addgroup -g ${PGID} appgroup && \
    adduser -u ${PUID} -G appgroup -S appuser

# Copy the script into the container
COPY main.sh /usr/local/bin/main.sh
COPY modules /usr/local/bin/modules

# Change ownership of the script to the non-root user and make it executable
RUN chown appuser:appgroup /usr/local/bin && \
    chown appuser:appgroup /usr/local/bin/main.sh && \
    chmod +x /usr/local/bin/main.sh && \
    chown -R appuser:appgroup /usr/local/bin/modules && \
    chmod -R +r /usr/local/bin/modules

# Switch to the non-root user
USER appuser

# Set the working directory
WORKDIR /usr/local/bin

# Run the script by default when the container starts
CMD ["/bin/bash", "/usr/local/bin/main.sh"]