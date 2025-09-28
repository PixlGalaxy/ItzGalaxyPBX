# ItzGalaxyPBX

**ItzGalaxyPBX** is a Dockerized PBX stack combining **Asterisk + FreePBX + chan_dongle**, designed to use a GSM/4G modem (e.g., SIM7600X) as a secure and modern gateway for calls and SMS.  
It automatically detects the modem’s AT/audio ports, generates `dongle.conf`, builds `chan_dongle` if missing, and applies hardened SIP/TLS/SRTP defaults.

---

## 🚀 Features

- **FreePBX + Asterisk in Docker** – Web UI for managing your PBX.  
- **chan_dongle support** – Make/receive calls and SMS with a SIM card.  
- **TLS + SRTP** – End-to-end encrypted SIP calls.  
- **Fail2ban ready** – Blocks brute-force SIP attacks automatically.  
- **.env-driven config** – All credentials, ports, and domains set in one file.  
- **Multi-arch Docker image** – Built for `amd64` and `arm64`.  

---

## Project structure

```
ItzGalaxyPBX/
├─ .env
├─ Dockerfile
├─ docker-compose.yml
├─ README.md
├─ scripts/
│  ├─ entrypoint.sh
│  ├─ setup-env.sh
│  ├─ init-dongle.sh
│  └─ cert-renew.sh
└─ config/
   ├─ asterisk/   (auto-generated configs)
   └─ fail2ban/   (jails and filters)
```

---

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/PixlGalaxy/ItzGalaxyPBX.git
   cd ItzGalaxyPBX
   ```

2. Copy `.env.example` → `.env` and edit values:
   ```dotenv
   PBX_DOMAIN=pbx.example.com
   SIP_TLS_PORT=5061
   SIP_RTP_START=10000
   SIP_RTP_END=20000
   EXT_200_USER=200
   EXT_200_PASS=ChangeThisPassword!
   FREEPBX_ADMIN_USER=admin
   FREEPBX_ADMIN_PASS=AdminPassword!
   ```

3. Build and start the container:
   ```bash
   docker compose up -d --build
   ```

4. Verify that the dongle is detected:
   ```bash
   docker exec -it itzgalaxypbx asterisk -rvvvvv
   dongle show devices
   ```

---

## SIP Client Setup (Groundwire Example)

- **Transport**: TLS  
- **Port**: 5061  
- **SRTP**: Required  
- **User**: `200`  
- **Password**: value from `.env` (`EXT_200_PASS`)
- **Domain/Proxy**: `pbx.example.com`  

---

## Security

- TLS/SRTP for all SIP traffic  
- Strong default passwords (from `.env`)  
- Fail2ban jail auto-configured for Asterisk logs  
- Expose only required ports:  
  - `5061/tcp` (SIP TLS)  
  - `10000-20000/udp` (RTP/SRTP)  
  - `443/tcp` (GUI behind reverse proxy recommended)  

---

## GHCR Docker Image

Images are automatically built and pushed to **GitHub Container Registry**:

```bash
docker pull ghcr.io/pixlgalaxy/itzgalaxypbx:latest
```

Tags available:
- `latest` – most recent main branch build  
- `sha` – commit-specific build  
- `vX.Y.Z` – versioned releases  

---

## Roadmap

- Multiple dongle support  
- WebSocket SIP proxy integration  
- SMS REST API endpoint  
- Improved FreePBX GUI hardening  

---

## License

MIT License © 2025 PixlGalaxy
