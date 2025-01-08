FROM alpine:latest

# Install required tools
RUN apk add --no-cache curl bash

# Copy the script into the container
COPY set_port.sh /usr/local/bin/set_port.sh

# Make the script executable
RUN chmod +x /usr/local/bin/set_port.sh

# Run the script by default when the container starts
CMD ["/bin/sh", "/usr/local/bin/set_port.sh"]
