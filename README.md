# wireguard-interno

Servidor WireGuard + portal web para distribuir archivos `.conf` de los
peers. Diseñado para uso **interno en la LAN**, sin QR ni pasos manuales:
la TV (o cualquier device) abre el portal, descarga su `.conf` y lo
importa en la app de WireGuard.

## Stack

- `linuxserver/wireguard` — server VPN
- `caddy` — portal web estático + endpoint de descarga de `.conf`
- `python` (script de bootstrap) — genera keys y .conf de los peers al
  primer arranque

## Setup

```bash
# 1. Clonar
git clone https://github.com/bramirezjofre/wireguard-interno.git
cd wireguard-interno

# 2. Configurar
cp .env.example .env
nano .env   # ajustar PIHOLE_DNS si querés

# 3. Levantar
docker compose up -d

# 4. Ver estado
docker compose logs -f wireguard
docker compose ps

# 5. Acceder al portal
# http://<ip-del-server>:8081
```

## Configurar un device (TV, celular, etc.)

1. Abrir `http://<ip>:8081` en el navegador del device
2. Click en el peer que querés (ej. `tv-living`)
3. Se descarga `tv-living.conf`
4. Abrir la app de WireGuard → "Importar desde archivo o archivo"
5. Activar el túnel

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `SERVER_IP` | 192.168.1.4 | IP del server en la LAN |
| `WG_PORT` | 51820 | Puerto UDP de WireGuard |
| `WG_NETWORK` | 10.14.14.0/24 | Subred de la VPN (lo que ven los peers) |
| `WG_SERVER_IP` | 10.14.14.1 | IP del server en la VPN |
| `PIHOLE_VPN_IP` | 10.14.15.2 | IP del pihole-vpn en la red Docker interna |
| `PEER_COUNT` | 5 | Cantidad de peers a generar |
| `ONBOARDING_PORT` | 8081 | Puerto del portal web |

## Arquitectura

```
[TV / celular]
    │
    │ descarga http://192.168.1.4:8081/peers/peer1.conf
    │ + importa en WireGuard app
    │
    ▼
[Caddy :8081] ──── sir ve archivos .conf
    │
    ▼
[WireGuard :51820 UDP] ──── server VPN (red 10.14.14.0/24)
    │
    │ push DNS = 10.14.15.2 (pihole-vpn)
    ▼
[Pihole VPN] ──── filtra y filtra (red Docker 10.14.15.0/24)
    │
    │ upstream
    ▼
[Pihole RPi 192.168.1.3] + [Pihole server-18 192.168.1.25]
```

Replica el patrón de `server-19`: wireguard + pihole en una red Docker
interna dedicada. El pihole-vpn actúa como el resolver DNS de los peers,
y delega al pihole de la RPi (que es el filtro principal de la LAN).

## Limitaciones

- **Sin seguridad adicional**: los `.conf` se descargan por HTTP plano.
  Para uso interno está bien; no exponer a internet.
- **No hay autenticación de usuarios**: cada peer tiene su propio keypair
  pregenerado. Si querés más seguridad, agregar autenticación externa.
- **No interfiere con la VPN externa** (server:19). Este es paralelo y
  solo para la LAN.

## Agregar más peers

Editar `PEER_COUNT` en `.env` y recrear:

```bash
docker compose down
# Regenerar configs
docker compose up -d
```

O agregar manualmente en `/config/wg_confs/wg0.conf` siguiendo el
formato del archivo generado.

## Archivos

- `docker-compose.yaml` — servicios
- `Caddyfile` — portal web
- `onboarding/` — página HTML estática
- `peers/` — directorio donde se generan los `.conf` (volumen Docker)
- `bootstrap.sh` — script de generación inicial de keys
- `.env.example` — template de variables
