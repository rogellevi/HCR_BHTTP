#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  HEX MANAGER - INSTALADOR AUTOMÁTICO
#  Repositorio: https://github.com/rogellevi/HCR_BHTTP
#  Uso: curl -sSL https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main/install.sh | bash
# ═══════════════════════════════════════════════════════════════

set -o pipefail
export DEBIAN_FRONTEND=noninteractive

# Colores
RED='\033[38;5;203m'
GREEN='\033[38;5;84m'
YELLOW='\033[38;5;221m'
CYAN='\033[38;5;51m'
WHITE='\033[38;5;255m'
NC='\033[0m'
BOLD='\033[1m'
ACC='\033[38;5;44m'
GRIS='\033[38;5;245m'

# Variables globales
GITHUB_RAW="https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main"
BHTTP_PORT=80
HCR_PORT=8080
BHTTP_BIN="/opt/bhttp/bhttp-server"
HCR_BIN="/opt/hcr/hcr-server"
USER_DB="/etc/hex/users.txt"
PORTS_CONF="/etc/hex/ports.conf"
LOG_FILE="/var/log/hex-installation.log"

# Funciones de UI
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

verificar_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗ Este script requiere permisos de root${NC}"
        echo -e "${YELLOW}Ejecuta: sudo bash install.sh${NC}"
        exit 1
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
    
    # Detener servicios si existen
    systemctl stop bhttp-server.service 2>/dev/null || true
    systemctl stop hcr-server.service 2>/dev/null || true
    systemctl disable bhttp-server.service 2>/dev/null || true
    systemctl disable hcr-server.service 2>/dev/null || true
    
    # Eliminar archivos de servicio
    rm -f /etc/systemd/system/bhttp-server.service
    rm -f /etc/systemd/system/hcr-server.service
    systemctl daemon-reload >/dev/null 2>&1
    
    ui_ok "Limpieza completada"
}

instalar_dependencias() {
    clear
    ui_top
    ui_titulo "1/6 INSTALANDO DEPENDENCIAS"
    ui_sep
    ui_fila ""
    
    ui_info "Actualizando repositorios..."
    apt-get update -y >/dev/null 2>&1
    
    ui_info "Instalando paquetes necesarios..."
    apt-get install -y curl wget systemd iptables ufw lsof >/dev/null 2>&1
    
    ui_ok "Dependencias instaladas"
    ui_fila ""
    sleep 1
}

descargar_binarios() {
    clear
    ui_top
    ui_titulo "2/6 DESCARGANDO BINARIOS"
    ui_sep
    ui_fila ""
    
    ARCH=$(detectar_arquitectura)
    
    # Crear directorios
    mkdir -p /opt/bhttp /opt/hcr /etc/hex /var/log/bhttp /var/log/hcr >/dev/null 2>&1
    
    # Descargar BHTTP
    ui_info "Descargando BHTTP ($ARCH)..."
    BHTTP_FILENAME="bhttp-server-v2.4.1-btun-compat-keepalive-linux-${ARCH}"
    BHTTP_URL="${GITHUB_RAW}/${BHTTP_FILENAME}"
    
    descargar_archivo "$BHTTP_URL" "$BHTTP_BIN"
    
    if [ -f "$BHTTP_BIN" ] && [ -s "$BHTTP_BIN" ]; then
        chmod +x "$BHTTP_BIN"
        ui_ok "BHTTP descargado correctamente"
    else
        ui_error "No se pudo descargar BHTTP"
        ui_error "Verifica tu conexión a internet"
        exit 1
    fi
    
    # Descargar HCR
    ui_info "Descargando HCR ($ARCH)..."
    HCR_FILENAME="hcr-server-linux-${ARCH}"
    HCR_URL="${GITHUB_RAW}/${HCR_FILENAME}"
    
    descargar_archivo "$HCR_URL" "$HCR_BIN"
    
    if [ -f "$HCR_BIN" ] && [ -s "$HCR_BIN" ]; then
        chmod +x "$HCR_BIN"
        ui_ok "HCR descargado correctamente"
    else
        ui_error "No se pudo descargar HCR"
        exit 1
    fi
    
    ui_fila ""
    sleep 1
}

configurar_servicios() {
    clear
    ui_top
    ui_titulo "3/6 CONFIGURANDO SERVICIOS"
    ui_sep
    ui_fila ""
    
    # Crear archivo de puertos
    echo "BHTTP_PORT=$BHTTP_PORT" > "$PORTS_CONF"
    echo "HCR_PORT=$HCR_PORT" >> "$PORTS_CONF"
    chmod 644 "$PORTS_CONF"
    
    # Crear base de datos de usuarios
    touch "$USER_DB"
    chmod 600 "$USER_DB"
    
    # Servicio BHTTP
    ui_info "Configurando servicio BHTTP..."
    cat > /etc/systemd/system/bhttp-server.service <<EOF
[Unit]
Description=BHTTP Server
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

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
    
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable bhttp-server.service >/dev/null 2>&1
    ui_ok "BHTTP configurado en puerto $BHTTP_PORT"
    
    # Servicio HCR
    ui_info "Configurando servicio HCR..."
    cat > /etc/systemd/system/hcr-server.service <<EOF
[Unit]
Description=HCR Server
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

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
    
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable hcr-server.service >/dev/null 2>&1
    ui_ok "HCR configurado en puerto $HCR_PORT"
    
    ui_fila ""
    sleep 1
}

instalar_menu() {
    clear
    ui_top
    ui_titulo "4/6 INSTALANDO MENÚ DE GESTIÓN"
    ui_sep
    ui_fila ""
    
    ui_info "Descargando script del menú..."
    MENU_URL="${GITHUB_RAW}/hex_menu.sh"
    
    descargar_archivo "$MENU_URL" "/usr/local/bin/hex_menu"
    
    if [ -f "/usr/local/bin/hex_menu" ] && [ -s "/usr/local/bin/hex_menu" ]; then
        chmod +x /usr/local/bin/hex_menu
        cp /usr/local/bin/hex_menu /usr/bin/hex_menu 2>/dev/null
        ui_ok "Menú instalado correctamente"
    else
        ui_error "No se pudo descargar el menú"
        exit 1
    fi
    
    ui_fila ""
    sleep 1
}

configurar_firewall() {
    clear
    ui_top
    ui_titulo "5/6 CONFIGURANDO FIREWALL"
    ui_sep
    ui_fila ""
    
    # Abrir puertos en iptables
    ui_info "Configurando iptables..."
    iptables -C INPUT -p tcp --dport $BHTTP_PORT -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport $BHTTP_PORT -j ACCEPT >/dev/null 2>&1
    iptables -C INPUT -p tcp --dport $HCR_PORT -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport $HCR_PORT -j ACCEPT >/dev/null 2>&1
    ui_ok "iptables configurado"
    
    # Abrir puertos en UFW si está disponible
    if command -v ufw >/dev/null 2>&1; then
        ui_info "Configurando UFW..."
        ufw allow $BHTTP_PORT/tcp >/dev/null 2>&1
        ufw allow $HCR_PORT/tcp >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
        ui_ok "UFW configurado"
    fi
    
    ui_fila ""
    sleep 1
}

iniciar_servicios() {
    clear
    ui_top
    ui_titulo "6/6 INICIANDO SERVICIOS"
    ui_sep
    ui_fila ""
    
    ui_info "Iniciando BHTTP..."
    systemctl start bhttp-server.service 2>>"$LOG_FILE"
    sleep 2
    if systemctl is-active --quiet bhttp-server.service; then
        ui_ok "BHTTP activo en puerto $BHTTP_PORT"
    else
        ui_warn "BHTTP no pudo iniciar (revisa con: journalctl -u bhttp-server -e)"
    fi
    
    ui_info "Iniciando HCR..."
    systemctl start hcr-server.service 2>>"$LOG_FILE"
    sleep 2
    if systemctl is-active --quiet hcr-server.service; then
        ui_ok "HCR activo en puerto $HCR_PORT"
    else
        ui_warn "HCR no pudo iniciar (revisa con: journalctl -u hcr-server -e)"
    fi
    
    ui_fila ""
    sleep 1
}

mostrar_resumen() {
    clear
    ui_top
    ui_titulo "✓ INSTALACIÓN COMPLETADA"
    ui_sep
    ui_fila ""
    
    bhttp_state=$(systemctl is-active bhttp-server.service 2>/dev/null || echo "inactivo")
    hcr_state=$(systemctl is-active hcr-server.service 2>/dev/null || echo "inactivo")
    
    [ "$bhttp_state" = "active" ] && bhttp_status="${GREEN}● ACTIVO${NC}" || bhttp_status="${RED}● INACTIVO${NC}"
    [ "$hcr_state" = "active" ] && hcr_status="${GREEN}● ACTIVO${NC}" || hcr_status="${RED}● INACTIVO${NC}"
    
    ui_fila "  ${CYAN}BHTTP${NC} - Puerto $BHTTP_PORT  $bhttp_status"
    ui_fila "  ${CYAN}HCR${NC}   - Puerto $HCR_PORT  $hcr_status"
    ui_fila ""
    ui_sep
    ui_fila ""
    ui_fila "  ${BOLD}Comando del menú:${NC}  ${YELLOW}hex_menu${NC}"
    ui_fila "  ${BOLD}IP del servidor:${NC}   ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
    ui_fila "  ${BOLD}Repositorio:${NC}       ${CYAN}https://github.com/rogellevi/HCR_BHTTP${NC}"
    ui_fila ""
    ui_sep
    ui_fila ""
    ui_fila "  ${GREEN}${BOLD}¡Instalación exitosa!${NC}"
    ui_fila "  ${GRIS}Ejecuta 'hex_menu' para gestionar usuarios y servicios${NC}"
    ui_fila ""
    ui_bot
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#  EJECUCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════

clear
ui_top
ui_titulo "HEX MANAGER - INSTALADOR"
ui_sep
ui_fila ""
ui_fila "  ${WHITE}Instalando BHTTP y HCR con gestión de usuarios${NC}"
ui_fila ""
ui_sep
ui_fila ""

# Crear log
: > "$LOG_FILE" 2>/dev/null

verificar_root
limpiar_instalacion_previa
instalar_dependencias
descargar_binarios
configurar_servicios
instalar_menu
configurar_firewall
iniciar_servicios
mostrar_resumen