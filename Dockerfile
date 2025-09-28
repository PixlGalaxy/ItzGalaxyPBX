# ItzGalaxyPBX - Dockerfile
# Base on maintained FreePBX + Asterisk image
FROM tiredofit/freepbx:latest

LABEL org.opencontainers.image.title="ItzGalaxyPBX" \
      org.opencontainers.image.description="Asterisk + FreePBX + chan_dongle with secure, .env-driven defaults" \
      org.opencontainers.image.source="https://github.com/<youruser>/ItzGalaxyPBX"

# Copy startup scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Let our entrypoint orchestrate startup, build chan_dongle if missing,
# render configs from .env, detect dongle ports, start services.
ENTRYPOINT ["/scripts/entrypoint.sh"]

# Informative expose (mapping is in docker-compose)
EXPOSE 5061/tcp 10000-20000/udp 443/tcp
