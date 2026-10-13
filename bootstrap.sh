#!/bin/bash
# Bootstrap de WireGuard: genera server keypair y configs de N peers
# si no existen. Pensado para correr al primer arranque.

set -e

WG_DIR="/config"
PEERS_DIR="/peers"
SERVER_IP="${SERVER_IP:-192.168.1.4}"
WG_PORT="${WG_PORT:-51820}"
WG_NETWORK="${WG_NETWORK:-10.14.14.0/24}"
WG_SERVER_IP="${WG_SERVER_IP:-10.14.14.1}"
PIHOLE_DNS="${PIHOLE_DNS:-192.168.1.3}"
PEER_COUNT="${PEER_COUNT:-5}"

# Si ya hay wg0.conf, no hacer nada
if [ -f "$WG_DIR/wg_confs/wg0.conf" ]; then
  echo "wg0.conf ya existe, no regenero"
  exit 0
fi

echo "=== Generando keypair del server ==="
mkdir -p "$WG_DIR/wg_confs" "$WG_DIR/server" "$PEERS_DIR"
chmod 700 "$WG_DIR/server"

SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)

# Generar N peers
echo "=== Generando $PEER_COUNT peers ==="
PEER_ENTRIES=""
for i in $(seq 1 "$PEER_COUNT"); do
  PEER_NAME="peer${i}"
  PEER_PRIV=$(wg genkey)
  PEER_PUB=$(echo "$PEER_PRIV" | wg pubkey)
  PEER_PSK=$(wg genpsk)
  PEER_IP="10.14.14.$((i + 1))"

  # Calcular AllowedIPs: red VPN + LAN (para que puedan ver la LAN)
  ALLOWED_IPS="10.14.14.0/24, 192.168.1.0/24"

  # Entrada para wg0.conf
  PEER_ENTRIES="${PEER_ENTRIES}
[Peer]
# ${PEER_NAME}
PublicKey = ${PEER_PUB}
PresharedKey = ${PEER_PSK}
AllowedIPs = ${PEER_IP}/32

"

  # Archivo .conf para el cliente
  cat > "$PEERS_DIR/${PEER_NAME}.conf" <<EOF
[Interface]
PrivateKey = ${PEER_PRIV}
Address = ${PEER_IP}/32
DNS = ${PIHOLE_DNS}

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${PEER_PSK}
Endpoint = ${SERVER_IP}:${WG_PORT}
AllowedIPs = ${ALLOWED_IPS}
PersistentKeepalive = 25
EOF

  chmod 600 "$PEERS_DIR/${PEER_NAME}.conf"
  echo "  Generado $PEER_NAME ($PEER_IP)"
done

# wg0.conf del server
cat > "$WG_DIR/wg_confs/wg0.conf" <<EOF
[Interface]
Address = ${WG_SERVER_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE
${PEER_ENTRIES}
EOF

chmod 600 "$WG_DIR/wg_confs/wg0.conf"

echo "=== Listo ==="
echo "Server pubkey: $SERVER_PUB"
echo "Peers generados en: $PEERS_DIR"
ls -la "$PEERS_DIR"
