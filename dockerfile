# Maintained upstream runtime; app source and repairs belong to this repository.
FROM docker.io/library/alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS runtime
ARG PUID=1000
ARG PGID=1000
ARG SOURCE_REVISION
LABEL org.opencontainers.image.source="https://github.com/jtmb/qbit-monitor" \
      org.opencontainers.image.revision="$SOURCE_REVISION"
ENV TZ=Etc/UTC
RUN apk add --no-cache curl jq tzdata grep bash \
    && addgroup -g "${PGID}" appgroup \
    && adduser -u "${PUID}" -G appgroup -S appuser \
    && mkdir -p /app/state \
    && chown appuser:appgroup /app /app/state
COPY --chown=appuser:appgroup main.sh /app/main.sh
COPY --chown=appuser:appgroup modules/ /app/modules/
RUN chmod 0755 /app/main.sh \
    && chmod -R a+rX /app/modules \
    && apk info -v > /usr/local/share/qbit-monitor-packages.txt
USER appuser
WORKDIR /app
CMD ["/bin/bash", "/app/main.sh"]
