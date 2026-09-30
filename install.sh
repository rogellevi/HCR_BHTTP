#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  HEX MANAGER - INSTALADOR AUTOMÁTICO (Con compilación de UDPGW)
#  Repositorio: https://github.com/rogellevi/HCR_BHTTP
# ═══════════════════════════════════════════════════════════════

set -o pipefail
export DEBIAN_FRONTEND=noninteractive

RED='\033[38;5;203m'
GREEN='\033[38;5;84m'
YELLOW='\033[38;5;221m'
CYAN='\033[38;5;51m'
WHITE='\033[38;5;255m'
NC='\033[0m'
BOLD='\033[1m'
ACC='\033[38;5;44m'
GRIS='\033[38;5;245m'

GITHUB_RAW="https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main"
BHTTP_PORT=80
HCR_PORT=8080
BHTTP_BIN="/opt/bhttp/bhttp-server"
HCR_BIN="/opt/hcr/hcr-server"
UDPGW_BIN="/opt/udpgw/udpgw-server"
USER_DB="/etc/hex/users.txt"
PORTS_CONF="/etc/hex/ports.conf"
UDPGW_PORTS_CONF="/etc/hex/udpgw_ports.conf"
LOG_FILE="/var/log/hex-installation.log"

ui_top() { echo -e "${ACC}╔════════════════════════════════════════════════════════════╗${NC}"; }
ui_sep() { echo -e "${ACC}╠════════════════════════════════════════════════════════════╣${NC}"; }
ui_bot() { echo -e "${ACC}╚════════════════════════════════════════════════════════════╝${NC}"; }
ui_fila() { echo -e "${ACC}║${NC} $1 ${ACC}║${NC}"; }
ui_titulo() { printf "${ACC}║${NC}                     ${WHITE}${BOLD}%s${NC}                     ${ACC}║${NC}\n" "$1"; }
ui_ok() { echo -e "     ${GREEN}✓${NC} ${WHITE}$1${NC}"; }
ui_error() { echo -e "     ${RED}✗${NC} ${RED}$1${NC}"; }
ui_info() { echo -e "     ${CYAN}ℹ${NC} ${GRIS}$1${NC}"; }
ui_warn() { echo -e "     ${YELLOW}⚠${NC} ${YELLOW}$1${NC}"; }

descargar_archivo() {
    local url="$1" destino="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 15 --max-time 600 --retry 3 -o "$destino" "$url" 2>>"$LOG_FILE"
    else
        wget -q --timeout=30 --tries=3 -O "$destino" "$url" 2>>"$LOG_FILE"
    fi
}

detectar_arquitectura() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) ui_error "Arquitectura no soportada: $(uname -m)"; exit 1 ;;
    esac
}

limpiar_instalacion_previa() {
    ui_info "Verificando instalación previa..."
    systemctl stop bhttp-server.service hcr-server.service 2>/dev/null || true
    systemctl disable bhttp-server.service hcr-server.service 2>/dev/null || true
    rm -f /etc/systemd/system/bhttp-server.service /etc/systemd/system/hcr-server.service /etc/systemd/system/udpgw@.service
    systemctl daemon-reload >/dev/null 2>&1
    ui_ok "Limpieza completada"
}

instalar_dependencias() {
    clear; ui_top; ui_titulo "1/6 INSTALANDO DEPENDENCIAS"; ui_sep; ui_fila ""
    ui_info "Actualizando repositorios e instalando paquetes..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl wget systemd iptables ufw lsof git cmake build-essential libssl-dev >/dev/null 2>&1
    ui_ok "Dependencias instaladas"; ui_fila ""; sleep 1
}

descargar_binarios() {
    clear; ui_top; ui_titulo "2/6 DESCARGANDO BINARIOS"; ui_sep; ui_fila ""
    ARCH=$(detectar_arquitectura)
    mkdir -p /opt/bhttp /opt/hcr /etc/hex /var/log/bhttp /var/log/hcr >/dev/null 2>&1
    
    ui_info "Descargando BHTTP ($ARCH)..."
    descargar_archivo "${GITHUB_RAW}/bhttp-server-v2.4.1-btun-compat-keepalive-linux-${ARCH}" "$BHTTP_BIN"
    [ -f "$BHTTP_BIN" ] && [ -s "$BHTTP_BIN" ] && chmod +x "$BHTTP_BIN" && ui_ok "BHTTP descargado" || { ui_error "Fallo al descargar BHTTP"; exit 1; }
    
    ui_info "Descargando HCR ($ARCH)..."
    descargar_archivo "${GITHUB_RAW}/hcr-server-linux-${ARCH}" "$HCR_BIN"
    [ -f "$HCR_BIN" ] && [ -s "$HCR_BIN" ] && chmod +x "$HCR_BIN" && ui_ok "HCR descargado" || { ui_error "Fallo al descargar HCR"; exit 1; }
    ui_fila ""; sleep 1
}

compilar_udpgw() {
    clear; ui_top; ui_titulo "3/6 COMPILANDO UDPGW (BadVPN)"; ui_sep; ui_fila ""
    ui_info "Descargando código fuente de BadVPN..."
    cd /tmp || exit 1
    rm -rf badvpn
    git clone https://github.com/ambrop72/badvpn.git >/dev/null 2>&1
    cd badvpn || exit 1
    mkdir -p build && cd build || exit 1
    
    ui_info "Compilando solo el módulo udpgw (esto puede tardar unos segundos)..."
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1
    make -j"$(nproc)" >/dev/null 2>&1
    
    if [ -f "udpgw/badvpn-udpgw" ]; then
        mkdir -p /opt/udpgw
        cp udpgw/badvpn-udpgw /opt/udpgw/udpgw-server
        chmod +x /opt/udpgw/udpgw-server
        ui_ok "UDPGW compilado e instalado en /opt/udpgw/udpgw-server"
    else
        ui_warn "La compilación de UDPGW falló (puedes continuar sin él)"
    fi
    cd /tmp || exit 1
    rm -rf badvpn
    ui_fila ""; sleep 1
}

configurar_servicios() {
    clear; ui_top; ui_titulo "4/6 CONFIGURANDO SERVICIOS"; ui_sep; ui_fila ""
    
    echo "BHTTP_PORT=$BHTTP_PORT" > "$PORTS_CONF"
    echo "HCR_PORT=$HCR_PORT" >> "$PORTS_CONF"
    echo -e "7300\n7301" > "$UDPGW_PORTS_CONF"
    touch "$USER_DB" && chmod 600 "$USER_DB"
    
    ui_info "Configurando BHTTP..."
    cat > /etc/systemd/system/bhttp-server.service <<EOF
[Unit]
Description=BHTTP Server
After=network.target
[Service]
Type=simple
User=root
ExecStart=$BHTTP_BIN -listen 0.0.0.0 -port $BHTTP_PORT -backend-host 127.0.0.1 -backend-port 22
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bhttp
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable bhttp-server.service >/dev/null 2>&1
    ui_ok "BHTTP configurado"

    ui_info "Configurando HCR..."
    cat > /etc/systemd/system/hcr-server.service <<EOF
[Unit]
Description=HCR Server
After=network.target
[Service]
Type=simple
User=root
ExecStart=$HCR_BIN --listen :$HCR_PORT --target 127.0.0.1:22 --transport plain
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hcr
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable hcr-server.service >/dev/null 2>&1
    ui_ok "HCR configurado"

    ui_info "Configurando plantilla UDPGW..."
    cat > /etc/systemd/system/udpgw@.service <<EOF
[Unit]
Description=BadVPN UDPGW Server on port %i
After=network.target
[Service]
Type=simple
User=root
ExecStart=$UDPGW_BIN --listen-addr 0.0.0.0:%i
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=udpgw-%i
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    ui_ok "Plantilla UDPGW configurada"
    ui_fila ""; sleep 1
}

instalar_menu_y_limpieza() {
    clear; ui_top; ui_titulo "5/6 INSTALANDO MENÚ Y LIMPIEZA"; ui_sep; ui_fila ""
    ui_info "Descargando menú de gestión..."
    descargar_archivo "${GITHUB_RAW}/hex_menu.sh" "/usr/local/bin/hex_menu"
    [ -f "/usr/local/bin/hex_menu" ] && chmod +x /usr/local/bin/hex_menu && cp /usr/local/bin/hex_menu /usr/bin/hex_menu 2>/dev/null && ui_ok "Menú instalado" || ui_error "Fallo al descargar menú"
    
    ui_info "Configurando limpieza automática..."
    cat > /usr/local/bin/hex_cleanup.sh <<'EOF_CLEANUP'
#!/bin/bash
USER_DB="/etc/hex/users.txt"
LOG_FILE="/var/log/hex-cleanup.log"
CURRENT_TIMESTAMP=$(date +%s)
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
[ ! -s "$USER_DB" ] && exit 0
deleted_count=0
while IFS=: read -r user pass exp; do
    [ -z "$user" ] && continue
    exp_timestamp=$(date -d "$exp" +%s 2>/dev/null || echo "0")
    if [ "$exp_timestamp" -lt "$CURRENT_TIMESTAMP" ]; then
        id "$user" >/dev/null 2>&1 && userdel -r "$user" 2>/dev/null
        sed -i "/^${user}:/d" "$USER_DB"
        ((deleted_count++))
    fi
done < "$USER_DB"
log "Limpieza completada. Eliminados: $deleted_count"
EOF_CLEANUP
    chmod +x /usr/local/bin/hex_cleanup.sh
    touch /var/log/hex-cleanup.log && chmod 644 /var/log/hex-cleanup.log
    (crontab -l 2>/dev/null | grep -v "hex_cleanup.sh"; echo "0 3 * * * /usr/local/bin/hex_cleanup.sh") | crontab -
    ui_ok "Limpieza automática activada (diaria 03:00 AM)"
    ui_fila ""; sleep 1
}

configurar_firewall_e_iniciar() {
    clear; ui_top; ui_titulo "6/6 FIREWALL E INICIO"; ui_sep; ui_fila ""
    
    # Firewall
    for port in $BHTTP_PORT $HCR_PORT; do
        iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $port -j ACCEPT
        command -v ufw >/dev/null 2>&1 && ufw allow $port/tcp >/dev/null 2>&1
    done
    
    # Iniciar UDPGW puertos por defecto
    if [ -f "$UDPGW_PORTS_CONF" ]; then
        while read -r port; do
            [ -z "$port" ] && continue
            systemctl enable "udpgw@${port}.service" >/dev/null 2>&1
            systemctl start "udpgw@${port}.service" 2>>"$LOG_FILE"
            iptables -I INPUT -p udp --dport $port -j ACCEPT 2>/dev/null
            iptables -I INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
            command -v ufw >/dev/null 2>&1 && { ufw allow $port/udp >/dev/null 2>&1; ufw allow $port/tcp >/dev/null 2>&1; }
        done < "$UDPGW_PORTS_CONF"
    fi
    
    systemctl start bhttp-server.service hcr-server.service 2>>"$LOG_FILE"
    ui_ok "Servicios iniciados y puertos abiertos"
    ui_fila ""; sleep 1
}

mostrar_resumen() {
    clear; ui_top; ui_titulo "✓ INSTALACIÓN COMPLETADA"; ui_sep; ui_fila ""
    bhttp_state=$(systemctl is-active bhttp-server.service 2>/dev/null || echo "inactivo")
    hcr_state=$(systemctl is-active hcr-server.service 2>/dev/null || echo "inactivo")
    [ "$bhttp_state" = "active" ] && bhttp_status="${GREEN}● ACTIVO${NC}" || bhttp_status="${RED}● INACTIVO${NC}"
    [ "$hcr_state" = "active" ] && hcr_status="${GREEN}● ACTIVO${NC}" || hcr_status="${RED}● INACTIVO${NC}"
    
    ui_fila "  ${CYAN}BHTTP${NC} - Puerto $BHTTP_PORT  $bhttp_status"
    ui_fila "  ${CYAN}HCR${NC}   - Puerto $HCR_PORT  $hcr_status"
    ui_fila "  ${CYAN}UDPGW${NC}  - Puertos 7300, 7301  ${GREEN}● ACTIVO${NC}"
    ui_fila ""
    ui_sep
    ui_fila "  ${BOLD}Comando:${NC}  ${YELLOW}hex_menu${NC}"
    ui_fila "  ${BOLD}IP:${NC}       ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
    ui_fila "  ${BOLD}Repo:${NC}     ${CYAN}github.com/rogellevi/HCR_BHTTP${NC}"
    ui_fila ""
    ui_bot; echo ""
}

# EJECUCIÓN
if [ "$EUID" -ne 0 ]; then echo -e "${RED}✗ Requiere root${NC}"; exit 1; fi
: > "$LOG_FILE" 2>/dev/null
limpiar_instalacion_previa
instalar_dependencias
descargar_binarios
compilar_udpgw
configurar_servicios
instalar_menu_y_limpieza
configurar_firewall_e_iniciar
mostrar_resumen