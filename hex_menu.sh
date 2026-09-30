#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  MANAGER - MENÚ DE GESTIÓN
#  Repositorio: https://github.com/rogellevi/HCR_BHTTP
# ═══════════════════════════════════════════════════════════════

RED='\033[38;5;203m'; GREEN='\033[38;5;84m'; YELLOW='\033[38;5;221m'
CYAN='\033[38;5;51m'; WHITE='\033[38;5;255m'; NC='\033[0m'
BOLD='\033[1m'; ACC='\033[38;5;44m'; GRIS='\033[38;5;245m'

BHTTP_UNIT="bhttp-server.service"
HCR_UNIT="hcr-server.service"
USER_DB="/etc/hex/users.txt"
USER_GROUP="hexusers"
PORTS_CONF="/etc/hex/ports.conf"
UDPGW_PORTS_CONF="/etc/hex/udpgw_ports.conf"
CLEANUP_SCRIPT="/usr/local/bin/hex_cleanup.sh"
CLEANUP_LOG="/var/log/hex-cleanup.log"

mkdir -p /etc/hex
touch "$USER_DB" && chmod 600 "$USER_DB"

[ -f "$PORTS_CONF" ] && source "$PORTS_CONF" || { BHTTP_PORT=80; HCR_PORT=8080; }
[ -f "$UDPGW_PORTS_CONF" ] || echo -e "7300\n7301" > "$UDPGW_PORTS_CONF"

# Instalación automática de limpieza al iniciar
if [ ! -f "$CLEANUP_SCRIPT" ]; then
    cat > "$CLEANUP_SCRIPT" <<'EOF_CLEANUP'
#!/bin/bash
USER_DB="/etc/hex/users.txt"; LOG_FILE="/var/log/hex-cleanup.log"; CURRENT_TIMESTAMP=$(date +%s)
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
[ ! -s "$USER_DB" ] && exit 0
deleted_count=0
while IFS=: read -r user pass exp; do
    [ -z "$user" ] && continue
    exp_timestamp=$(date -d "$exp" +%s 2>/dev/null || echo "0")
    if [ "$exp_timestamp" -lt "$CURRENT_TIMESTAMP" ]; then
        id "$user" >/dev/null 2>&1 && userdel -r "$user" 2>/dev/null
        sed -i "/^${user}:/d" "$USER_DB"; ((deleted_count++))
    fi
done < "$USER_DB"
log "Limpieza completada. Eliminados: $deleted_count"
EOF_CLEANUP
    chmod +x "$CLEANUP_SCRIPT"
    touch "$CLEANUP_LOG" && chmod 644 "$CLEANUP_LOG"
fi
cron_active=$(crontab -l 2>/dev/null | grep -c "hex_cleanup.sh")
[ "$cron_active" -eq 0 ] && (crontab -l 2>/dev/null; echo "0 3 * * * $CLEANUP_SCRIPT") | crontab -

pause_return() { echo ""; echo -e "  ${CYAN}Presiona ENTER para continuar...${NC}"; read -r; }
ui_top() { echo -e "${ACC}╔════════════════════════════════════════════════════════════╗${NC}"; }
ui_sep() { echo -e "${ACC}╠════════════════════════════════════════════════════════════╣${NC}"; }
ui_bot() { echo -e "${ACC}╚════════════════════════════════════════════════════════════╝${NC}"; }
ui_fila() { echo -e "${ACC}║${NC} $1 ${ACC}║${NC}"; }
ui_titulo() { printf "${ACC}║${NC}                     ${WHITE}${BOLD}%s${NC}                     ${ACC}║${NC}\n" "$1"; }
ui_opcion() { printf "     ${CYAN}[${NC}${YELLOW}$1${NC}${CYAN}]${NC}  $2\n"; }

menu_principal() {
    clear; ui_top; ui_titulo "MENÚ DE GESTIÓN"; ui_sep
    
    bhttp_state=$(systemctl is-active $BHTTP_UNIT 2>/dev/null || echo "inactivo")
    hcr_state=$(systemctl is-active $HCR_UNIT 2>/dev/null || echo "inactivo")
    [ "$bhttp_state" = "active" ] && bhttp_status="${GREEN}● ACTIVO${NC}" || bhttp_status="${RED}● INACTIVO${NC}"
    [ "$hcr_state" = "active" ] && hcr_status="${GREEN}● ACTIVO${NC}" || hcr_status="${RED}● INACTIVO${NC}"
    
    [ "$cron_active" -gt 0 ] && cleanup_status="${GREEN}● ACTIVO${NC}" || cleanup_status="${RED}● INACTIVO${NC}"
    
    udpgw_total=0; udpgw_active=0
    if [ -f "$UDPGW_PORTS_CONF" ]; then
        while read -r port; do
            [ -z "$port" ] && continue; ((udpgw_total++))
            systemctl is-active --quiet "udpgw@${port}.service" 2>/dev/null && ((udpgw_active++))
        done < "$UDPGW_PORTS_CONF"
    fi
    [ "$udpgw_total" -eq 0 ] && udpgw_status="${RED}● SIN PUERTOS${NC}"
    [ "$udpgw_active" -eq "$udpgw_total" ] && [ "$udpgw_total" -gt 0 ] && udpgw_status="${GREEN}● ACTIVO ($udpgw_active/$udpgw_total)${NC}"
    [ "$udpgw_active" -gt 0 ] && [ "$udpgw_active" -lt "$udpgw_total" ] && udpgw_status="${YELLOW}● PARCIAL ($udpgw_active/$udpgw_total)${NC}"
    [ "$udpgw_active" -eq 0 ] && [ "$udpgw_total" -gt 0 ] && udpgw_status="${RED}● INACTIVO (0/$udpgw_total)${NC}"
    
    ui_fila ""
    ui_fila "  ${CYAN}BHTTP${NC}     - Puerto $BHTTP_PORT       $bhttp_status"
    ui_fila "  ${CYAN}HCR${NC}       - Puerto $HCR_PORT       $hcr_status"
    ui_fila "  ${CYAN}UDPGW${NC}     - $udpgw_total puertos        $udpgw_status"
    ui_fila "  ${CYAN}LIMPIADOR${NC} - Diario 03:00       $cleanup_status"
    ui_fila ""; ui_sep
    
    ui_opcion "1" "Gestionar BHTTP"
    ui_opcion "2" "Gestionar HCR"
    ui_opcion "3" "Gestionar UDPGW"
    ui_opcion "4" "Agregar usuario"
    ui_opcion "5" "Eliminar usuario"
    ui_opcion "6" "Listar usuarios activos"
    ui_opcion "7" "Configurar puertos BHTTP/HCR"
    ui_opcion "8" "Limpieza automática"
    ui_opcion "9" "Ver logs"
    ui_opcion "10" "Desinstalar"
    ui_opcion "0" "Salir"
    
    ui_bot; echo ""
    echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opcion
    
    case "$opcion" in
        1) menu_bhttp ;; 2) menu_hcr ;; 3) menu_udpgw ;; 4) agregar_usuario ;;
        5) eliminar_usuario ;; 6) listar_usuarios ;; 7) configurar_puertos ;;
        8) gestionar_limpieza ;; 9) ver_logs ;; 10) desinstalar ;; 0) exit 0 ;;
        *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return; menu_principal ;;
    esac
}

# --- FUNCIONES BHTTP / HCR (Simplificadas para espacio, funcionan igual que antes) ---
menu_bhttp() {
    while true; do
        clear; ui_top; ui_titulo "GESTIÓN BHTTP"; ui_sep
        bhttp_state=$(systemctl is-active $BHTTP_UNIT 2>/dev/null || echo "inactivo")
        [ "$bhttp_state" = "active" ] && bhttp_status="${GREEN}● ACTIVO${NC}" || bhttp_status="${RED}● INACTIVO${NC}"
        ui_fila "  Estado: $bhttp_status  │  Puerto: ${YELLOW}$BHTTP_PORT${NC}"; ui_sep; ui_fila ""
        ui_opcion "1" "Iniciar"; ui_opcion "2" "Detener"; ui_opcion "3" "Reiniciar"; ui_opcion "4" "Ver estado"; ui_opcion "0" "Atrás"
        ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
        case "$opt" in
            1) systemctl start $BHTTP_UNIT; echo -e "  ${GREEN}✓ BHTTP iniciado${NC}"; pause_return ;;
            2) systemctl stop $BHTTP_UNIT; echo -e "  ${GREEN}✓ BHTTP detenido${NC}"; pause_return ;;
            3) systemctl restart $BHTTP_UNIT; echo -e "  ${GREEN}✓ BHTTP reiniciado${NC}"; pause_return ;;
            4) echo ""; systemctl status $BHTTP_UNIT --no-pager; pause_return ;;
            0) break ;; *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
        esac
    done; menu_principal
}

menu_hcr() {
    while true; do
        clear; ui_top; ui_titulo "GESTIÓN HCR"; ui_sep
        hcr_state=$(systemctl is-active $HCR_UNIT 2>/dev/null || echo "inactivo")
        [ "$hcr_state" = "active" ] && hcr_status="${GREEN}● ACTIVO${NC}" || hcr_status="${RED}● INACTIVO${NC}"
        ui_fila "  Estado: $hcr_status  │  Puerto: ${YELLOW}$HCR_PORT${NC}"; ui_sep; ui_fila ""
        ui_opcion "1" "Iniciar"; ui_opcion "2" "Detener"; ui_opcion "3" "Reiniciar"; ui_opcion "4" "Ver estado"; ui_opcion "0" "Atrás"
        ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
        case "$opt" in
            1) systemctl start $HCR_UNIT; echo -e "  ${GREEN}✓ HCR iniciado${NC}"; pause_return ;;
            2) systemctl stop $HCR_UNIT; echo -e "  ${GREEN}✓ HCR detenido${NC}"; pause_return ;;
            3) systemctl restart $HCR_UNIT; echo -e "  ${GREEN}✓ HCR reiniciado${NC}"; pause_return ;;
            4) echo ""; systemctl status $HCR_UNIT --no-pager; pause_return ;;
            0) break ;; *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
        esac
    done; menu_principal
}

# --- FUNCIONES UDPGW ---
menu_udpgw() {
    while true; do
        clear; ui_top; ui_titulo "GESTIÓN UDPGW"; ui_sep; echo ""
        echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${CYAN}║${NC}  ${WHITE}${BOLD}Puerto     Estado              Backend${NC}                   ${CYAN}║${NC}"
        echo -e "  ${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        
        udpgw_count=0
        if [ -f "$UDPGW_PORTS_CONF" ]; then
            while read -r port; do
                [ -z "$port" ] && continue; ((udpgw_count++))
                systemctl is-active --quiet "udpgw@${port}.service" 2>/dev/null && status="${GREEN}● ACTIVO${NC}    " || status="${RED}● INACTIVO${NC}  "
                printf "  ${CYAN}║${NC}  ${YELLOW}%-10s${NC} %b  ${GRIS}0.0.0.0 (Gateway)${NC}          ${CYAN}║${NC}\n" "$port" "$status"
            done < "$UDPGW_PORTS_CONF"
        fi
        [ "$udpgw_count" -eq 0 ] && echo -e "  ${CYAN}║${NC}  ${YELLOW}No hay puertos configurados${NC}                            ${CYAN}║${NC}"
        echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"; echo ""
        ui_sep; ui_fila ""
        
        ui_opcion "1" "Agregar puerto"; ui_opcion "2" "Eliminar puerto"
        ui_opcion "3" "Iniciar todos"; ui_opcion "4" "Detener todos"; ui_opcion "5" "Reiniciar todos"
        ui_opcion "6" "Control individual"; ui_opcion "0" "Atrás"
        ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
        
        case "$opt" in
            1) udpgw_agregar_puerto ;; 2) udpgw_eliminar_puerto ;; 3) udpgw_iniciar_todos; pause_return ;;
            4) udpgw_detener_todos; pause_return ;; 5) udpgw_reiniciar_todos; pause_return ;;
            6) udpgw_control_individual; pause_return ;; 0) break ;; *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
        esac
    done; menu_principal
}

udpgw_agregar_puerto() {
    clear; ui_top; ui_titulo "AGREGAR PUERTO UDPGW"; ui_sep; ui_fila ""
    echo -ne "  ${WHITE}Número de puerto:${NC} "; read -r new_port
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "  ${RED}✗ Puerto inválido${NC}"; pause_return; return
    fi
    grep -qw "^$new_port$" "$UDPGW_PORTS_CONF" 2>/dev/null && { echo -e "  ${RED}✗ El puerto ya está configurado${NC}"; pause_return; return; }
    ss -tuln | grep -q ":$new_port " && { echo -e "  ${RED}✗ El puerto ya está en uso${NC}"; pause_return; return; }
    
    echo "$new_port" >> "$UDPGW_PORTS_CONF"
    iptables -I INPUT -p udp --dport $new_port -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport $new_port -j ACCEPT 2>/dev/null
    command -v ufw >/dev/null 2>&1 && { ufw allow $new_port/udp >/dev/null 2>&1; ufw allow $new_port/tcp >/dev/null 2>&1; }
    
    systemctl enable "udpgw@${new_port}.service" >/dev/null 2>&1
    systemctl start "udpgw@${new_port}.service" 2>/dev/null
    sleep 1
    systemctl is-active --quiet "udpgw@${new_port}.service" 2>/dev/null && echo -e "  ${GREEN}✓ Puerto $new_port agregado y activo${NC}" || echo -e "  ${YELLOW}⚠ Puerto agregado pero no inició${NC}"
    pause_return
}

udpgw_eliminar_puerto() {
    clear; ui_top; ui_titulo "ELIMINAR PUERTO UDPGW"; ui_sep; ui_fila ""
    [ ! -s "$UDPGW_PORTS_CONF" ] && { echo -e "  ${YELLOW}No hay puertos configurados${NC}"; pause_return; return; }
    
    echo -e "  ${CYAN}Puertos actuales:${NC}"; echo ""
    counter=1
    while read -r port; do
        [ -z "$port" ] && continue
        systemctl is-active --quiet "udpgw@${port}.service" 2>/dev/null && status="${GREEN}● ACTIVO${NC}" || status="${RED}● INACTIVO${NC}"
        printf "    ${YELLOW}[%s]${NC} Puerto ${WHITE}%s${NC}  %b\n" "$counter" "$port" "$status"; ((counter++))
    done < "$UDPGW_PORTS_CONF"
    echo ""
    
    echo -ne "  ${WHITE}Número de puerto a eliminar:${NC} "; read -r del_port
    grep -qw "^$del_port$" "$UDPGW_PORTS_CONF" || { echo -e "  ${RED}✗ El puerto no existe${NC}"; pause_return; return; }
    
    systemctl stop "udpgw@${del_port}.service" 2>/dev/null
    systemctl disable "udpgw@${del_port}.service" 2>/dev/null
    sed -i "/^${del_port}$/d" "$UDPGW_PORTS_CONF"
    iptables -D INPUT -p udp --dport $del_port -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport $del_port -j ACCEPT 2>/dev/null
    command -v ufw >/dev/null 2>&1 && { ufw delete allow $del_port/udp >/dev/null 2>&1; ufw delete allow $del_port/tcp >/dev/null 2>&1; }
    
    echo -e "  ${GREEN}✓ Puerto $del_port eliminado completamente${NC}"; pause_return
}

udpgw_iniciar_todos() {
    echo -e "  ${CYAN}Iniciando todos los puertos UDPGW...${NC}"
    [ -f "$UDPGW_PORTS_CONF" ] && while read -r port; do [ -z "$port" ] && continue; systemctl start "udpgw@${port}.service" 2>/dev/null; echo -e "  ${GREEN}✓ Puerto $port iniciado${NC}"; done < "$UDPGW_PORTS_CONF"
}
udpgw_detener_todos() {
    echo -e "  ${CYAN}Deteniendo todos los puertos UDPGW...${NC}"
    [ -f "$UDPGW_PORTS_CONF" ] && while read -r port; do [ -z "$port" ] && continue; systemctl stop "udpgw@${port}.service" 2>/dev/null; echo -e "  ${GREEN}✓ Puerto $port detenido${NC}"; done < "$UDPGW_PORTS_CONF"
}
udpgw_reiniciar_todos() {
    echo -e "  ${CYAN}Reiniciando todos los puertos UDPGW...${NC}"
    [ -f "$UDPGW_PORTS_CONF" ] && while read -r port; do [ -z "$port" ] && continue; systemctl restart "udpgw@${port}.service" 2>/dev/null; echo -e "  ${GREEN}✓ Puerto $port reiniciado${NC}"; done < "$UDPGW_PORTS_CONF"
}

udpgw_control_individual() {
    clear; ui_top; ui_titulo "CONTROL INDIVIDUAL UDPGW"; ui_sep; ui_fila ""
    echo -e "  ${CYAN}Puertos disponibles:${NC}"; echo ""
    counter=1
    while read -r port; do
        [ -z "$port" ] && continue
        systemctl is-active --quiet "udpgw@${port}.service" 2>/dev/null && status="${GREEN}● ACTIVO${NC}" || status="${RED}● INACTIVO${NC}"
        printf "    ${YELLOW}[%s]${NC} Puerto ${WHITE}%s${NC}  %b\n" "$counter" "$port" "$status"; ((counter++))
    done < "$UDPGW_PORTS_CONF"
    echo ""; echo -ne "  ${WHITE}Número de puerto:${NC} "; read -r target_port
    grep -qw "^$target_port$" "$UDPGW_PORTS_CONF" || { echo -e "  ${RED}✗ Puerto no encontrado${NC}"; return; }
    
    echo ""; echo -e "  ${CYAN}Acciones para puerto $target_port:${NC}"; echo ""
    ui_opcion "1" "Iniciar"; ui_opcion "2" "Detener"; ui_opcion "3" "Reiniciar"; ui_opcion "4" "Ver estado"; ui_opcion "0" "Cancelar"
    echo ""; echo -ne "  ${CYAN}►${NC} Opción: "; read -r action
    case "$action" in
        1) systemctl start "udpgw@${target_port}.service"; echo -e "  ${GREEN}✓ Iniciado${NC}" ;;
        2) systemctl stop "udpgw@${target_port}.service"; echo -e "  ${GREEN}✓ Detenido${NC}" ;;
        3) systemctl restart "udpgw@${target_port}.service"; echo -e "  ${GREEN}✓ Reiniciado${NC}" ;;
        4) systemctl status "udpgw@${target_port}.service" --no-pager ;;
        0) return ;; *) echo -e "  ${RED}✗ Opción inválida${NC}" ;;
    esac
}

# --- FUNCIONES DE USUARIOS (Mismas que antes, abreviadas para espacio) ---
agregar_usuario() {
    clear; ui_top; ui_titulo "AGREGAR USUARIO"; ui_sep
    getent group "$USER_GROUP" >/dev/null 2>&1 || groupadd "$USER_GROUP" 2>/dev/null
    echo ""; echo -ne "  ${WHITE}Usuario:${NC} "; read -r new_user
    [[ "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo -e "  ${RED}✗ Nombre inválido${NC}"; pause_return; menu_principal; return; }
    id "$new_user" >/dev/null 2>&1 && { echo -e "  ${RED}✗ El usuario ya existe${NC}"; pause_return; menu_principal; return; }
    echo -ne "  ${WHITE}Contraseña:${NC} "; read -rs new_pass; echo ""
    [ -z "$new_pass" ] && { echo -e "  ${RED}✗ Contraseña vacía${NC}"; pause_return; menu_principal; return; }
    echo -ne "  ${WHITE}Validez (días):${NC} "; read -r days
    [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "  ${RED}✗ Días inválidos${NC}"; pause_return; menu_principal; return; }
    
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    useradd -m -s /bin/bash -G "$USER_GROUP" "$new_user" 2>/dev/null
    echo "$new_user:$new_pass" | chpasswd
    chage -E "$exp_date" "$new_user" && usermod -e "$exp_date" "$new_user"
    echo "${new_user}:${new_pass}:${exp_date}" >> "$USER_DB"
    
    echo ""; echo -e "  ${GREEN}✓ Usuario creado exitosamente${NC}"
    echo -e "  ${BOLD}IP:${NC} $(hostname -I | awk '{print $1}') | ${BOLD}BHTTP:${NC} $BHTTP_PORT | ${BOLD}HCR:${NC} $HCR_PORT"
    echo -e "  ${BOLD}Usuario:${NC} ${YELLOW}${new_user}${NC} | ${BOLD}Pass:${NC} ${YELLOW}${new_pass}${NC} | ${BOLD}Expira:${NC} ${YELLOW}${exp_date}${NC}"; echo ""
    pause_return; menu_principal
}

eliminar_usuario() {
    clear; ui_top; ui_titulo "ELIMINAR USUARIO"; ui_sep
    [ ! -s "$USER_DB" ] && { echo -e "  ${YELLOW}No hay usuarios${NC}"; pause_return; menu_principal; return; }
    echo ""; echo -e "  ${CYAN}Usuarios activos:${NC}"; echo ""
    cat -n "$USER_DB" | awk -F: '{printf "    ${YELLOW}[%s]${NC} %s (Exp: %s)\n", NR, $1, $3}' | sed "s/\${YELLOW}/\x1b[38;5;221m/g; s/\${NC}/\x1b[0m/g"; echo ""
    echo -ne "  ${WHITE}Usuario a eliminar:${NC} "; read -r del_user
    id "$del_user" >/dev/null 2>&1 || { echo -e "  ${RED}✗ No existe${NC}"; pause_return; menu_principal; return; }
    userdel -r "$del_user" 2>/dev/null; sed -i "/^$del_user:/d" "$USER_DB"
    echo -e "  ${GREEN}✓ Usuario eliminado${NC}"; pause_return; menu_principal
}

listar_usuarios() {
    clear; ui_top; ui_titulo "USUARIOS ACTIVOS"; ui_sep
    [ ! -s "$USER_DB" ] && { echo ""; echo -e "  ${YELLOW}⚠ No hay usuarios registrados${NC}"; ui_sep; ui_fila ""; ui_fila "  ${GRIS}Usa la opción 4 para agregar usuarios${NC}"; ui_fila ""; pause_return; menu_principal; return; }
    
    total_users=$(wc -l < "$USER_DB"); active_users=0; expired_users=0; expiring_soon=0
    current_timestamp=$(date +%s)
    
    echo ""; echo -e "  ${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC} ${WHITE}${BOLD}#   Usuario          Contraseña      Expira          Días Rest.  Estado${NC}          ${CYAN}║${NC}"
    echo -e "  ${CYAN}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    counter=1
    while IFS=: read -r user pass exp; do
        if id "$user" >/dev/null 2>&1; then
            exp_timestamp=$(date -d "$exp" +%s 2>/dev/null || echo "0")
            days_left=$(( (exp_timestamp - current_timestamp) / 86400 ))
            
            if [ "$exp_timestamp" -lt "$current_timestamp" ]; then
                status="${RED}● EXPIRADO${NC}"; days_color="${RED}"; ((expired_users++))
            elif [ "$days_left" -le 3 ]; then
                status="${YELLOW}● POR EXPIRAR${NC}"; days_color="${YELLOW}"; ((expiring_soon++))
            else
                status="${GREEN}● ACTIVO${NC}"; days_color="${GREEN}"; ((active_users++))
            fi
            
            [ ${#pass} -gt 3 ] && pass_masked="${pass:0:3}***" || pass_masked="***"
            printf "  ${CYAN}║${NC} ${YELLOW}%-3s${NC} ${WHITE}%-16s${NC} ${GRIS}%-15s${NC} ${WHITE}%-15s${NC} ${days_color}%-11s${NC} %b\n" "$counter" "$user" "$pass_masked" "$exp" "$days_left" "$status"
            ((counter++))
        fi
    done < "$USER_DB"
    
    echo -e "  ${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"; echo ""
    ui_sep; echo ""
    echo -e "  ${BOLD}RESUMEN:${NC}"; echo -e "  Total: ${WHITE}$total_users${NC} | Activos: ${GREEN}$active_users${NC} | Por expirar: ${YELLOW}$expiring_soon${NC} | Expirados: ${RED}$expired_users${NC}"; echo ""
    ui_sep; ui_fila ""; pause_return; menu_principal
}

configurar_puertos() {
    clear; ui_top; ui_titulo "CONFIGURAR PUERTOS"; ui_sep; ui_fila ""
    ui_fila "  ${CYAN}Puertos actuales:${NC}"; ui_fila "  BHTTP: ${YELLOW}$BHTTP_PORT${NC}"; ui_fila "  HCR:   ${YELLOW}$HCR_PORT${NC}"; ui_fila ""; ui_sep; ui_fila ""
    
    echo -ne "  ${WHITE}Nuevo puerto BHTTP (actual: $BHTTP_PORT):${NC} "; read -r new_bhttp_port
    if [ -n "$new_bhttp_port" ]; then
        [[ "$new_bhttp_port" =~ ^[0-9]+$ ]] && [ "$new_bhttp_port" -ge 1 ] && [ "$new_bhttp_port" -le 65535 ] || { echo -e "  ${RED}✗ Puerto inválido${NC}"; pause_return; menu_principal; return; }
        ss -tuln | grep -q ":$new_bhttp_port " && { echo -e "  ${RED}✗ Puerto en uso${NC}"; pause_return; menu_principal; return; }
        BHTTP_PORT=$new_bhttp_port
    fi
    
    echo -ne "  ${WHITE}Nuevo puerto HCR (actual: $HCR_PORT):${NC} "; read -r new_hcr_port
    if [ -n "$new_hcr_port" ]; then
        [[ "$new_hcr_port" =~ ^[0-9]+$ ]] && [ "$new_hcr_port" -ge 1 ] && [ "$new_hcr_port" -le 65535 ] || { echo -e "  ${RED}✗ Puerto inválido${NC}"; pause_return; menu_principal; return; }
        ss -tuln | grep -q ":$new_hcr_port " && { echo -e "  ${RED}✗ Puerto en uso${NC}"; pause_return; menu_principal; return; }
        HCR_PORT=$new_hcr_port
    fi
    
    echo "BHTTP_PORT=$BHTTP_PORT" > "$PORTS_CONF"; echo "HCR_PORT=$HCR_PORT" >> "$PORTS_CONF"
    sed -i "s|-port [0-9]\+|-port $BHTTP_PORT|g" /etc/systemd/system/bhttp-server.service
    sed -i "s|--listen :[0-9]\+|--listen :$HCR_PORT|g" /etc/systemd/system/hcr-server.service
    systemctl daemon-reload >/dev/null 2>&1
    
    for port in $BHTTP_PORT $HCR_PORT; do
        iptables -I INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
        command -v ufw >/dev/null 2>&1 && ufw allow $port/tcp >/dev/null 2>&1
    done
    systemctl restart $BHTTP_UNIT $HCR_UNIT 2>/dev/null
    
    echo ""; echo -e "  ${GREEN}✓ Puertos actualizados${NC}"; echo -e "  ${BOLD}BHTTP:${NC} $BHTTP_PORT | ${BOLD}HCR:${NC} $HCR_PORT"; echo ""
    pause_return; menu_principal
}

gestionar_limpieza() {
    clear; ui_top; ui_titulo "LIMPIEZA AUTOMÁTICA"; ui_sep; ui_fila ""
    cron_active=$(crontab -l 2>/dev/null | grep -c "hex_cleanup.sh")
    
    if [ "$cron_active" -gt 0 ]; then
        ui_fila "  Estado: ${GREEN}● ACTIVO${NC}"; ui_fila "  ${GRIS}Se ejecuta diariamente a las 03:00 AM${NC}"; ui_fila ""
        ui_sep; ui_fila ""
        ui_opcion "1" "Desactivar limpieza automática"; ui_opcion "2" "Ejecutar limpieza manual AHORA"; ui_opcion "3" "Ver log de limpieza"; ui_opcion "0" "Atrás"
        ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
        case "$opt" in
            1) crontab -l 2>/dev/null | grep -v "hex_cleanup.sh" | crontab -; echo -e "  ${GREEN}✓ Desactivada${NC}"; pause_return ;;
            2) echo -e "  ${CYAN}Ejecutando...${NC}"; $CLEANUP_SCRIPT; echo -e "  ${GREEN}✓ Completada${NC}"; pause_return ;;
            3) [ -f "$CLEANUP_LOG" ] && tail -50 "$CLEANUP_LOG" | less || { echo -e "  ${YELLOW}Sin log${NC}"; pause_return; } ;;
            0) ;; *) echo -e "  ${RED}✗ Inválida${NC}"; pause_return ;;
        esac
    else
        ui_fila "  Estado: ${RED}● INACTIVO${NC}"; ui_fila "  ${GRIS}Los usuarios expirados NO se eliminan automáticamente${NC}"; ui_fila ""
        ui_sep; ui_fila ""
        ui_opcion "1" "Activar limpieza automática"; ui_opcion "2" "Ejecutar limpieza manual AHORA"; ui_opcion "3" "Ver log de limpieza"; ui_opcion "0" "Atrás"
        ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
        case "$opt" in
            1) (crontab -l 2>/dev/null; echo "0 3 * * * $CLEANUP_SCRIPT") | crontab -; echo -e "  ${GREEN}✓ Activada${NC}"; pause_return ;;
            2) echo -e "  ${CYAN}Ejecutando...${NC}"; $CLEANUP_SCRIPT; echo -e "  ${GREEN}✓ Completada${NC}"; pause_return ;;
            3) [ -f "$CLEANUP_LOG" ] && tail -50 "$CLEANUP_LOG" | less || { echo -e "  ${YELLOW}Sin log${NC}"; pause_return; } ;;
            0) ;; *) echo -e "  ${RED}✗ Inválida${NC}"; pause_return ;;
        esac
    fi
    menu_principal
}

ver_logs() {
    clear; ui_top; ui_titulo "VER LOGS"; ui_sep; ui_fila ""
    ui_opcion "1" "BHTTP (últimas 50)"; ui_opcion "2" "HCR (últimas 50)"; ui_opcion "3" "UDPGW (todos)"
    ui_opcion "4" "BHTTP (todas)"; ui_opcion "5" "HCR (todas)"; ui_opcion "6" "Limpieza automática"; ui_opcion "0" "Atrás"
    ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
    
    case "$opt" in
        1) echo ""; journalctl -u $BHTTP_UNIT -n 50 --no-pager; pause_return ;;
        2) echo ""; journalctl -u $HCR_UNIT -n 50 --no-pager; pause_return ;;
        3) echo ""; [ -f "$UDPGW_PORTS_CONF" ] && while read -r port; do [ -z "$port" ] && continue; echo -e "${YELLOW}═══ Puerto $port ═══${NC}"; journalctl -u "udpgw@${port}.service" -n 20 --no-pager; echo ""; done < "$UDPGW_PORTS_CONF" || echo -e "  ${YELLOW}Sin puertos${NC}"; pause_return ;;
        4) journalctl -u $BHTTP_UNIT --no-pager | less ;;
        5) journalctl -u $HCR_UNIT --no-pager | less ;;
        6) [ -f "$CLEANUP_LOG" ] && tail -100 "$CLEANUP_LOG" | less || { echo -e "  ${YELLOW}Sin log${NC}"; pause_return; } ;;
        0) ;; *) echo -e "  ${RED}✗ Inválida${NC}"; pause_return ;;
    esac
    menu_principal
}

desinstalar() {
    clear; ui_top; ui_titulo "DESINSTALAR"; ui_sep; ui_fila ""; ui_fila "  ${YELLOW}⚠${NC}  Estás a punto de desinstalar"; ui_fila ""; ui_sep
    echo ""; echo -ne "  ${RED}✗ Escriba${NC} ${YELLOW}${BOLD}CONFIRMAR${NC} ${RED}para continuar:${NC} "; read -r confirm
    
    if [ "$confirm" = "CONFIRMAR" ]; then
        echo -e "  ${CYAN}Deteniendo servicios...${NC}"
        systemctl stop $BHTTP_UNIT $HCR_UNIT 2>/dev/null || true
        [ -f "$UDPGW_PORTS_CONF" ] && while read -r port; do [ -z "$port" ] && continue; systemctl stop "udpgw@${port}.service" 2>/dev/null || true; done < "$UDPGW_PORTS_CONF"
        
        echo -e "  ${CYAN}Eliminando archivos...${NC}"
        rm -f /etc/systemd/system/bhttp-server.service /etc/systemd/system/hcr-server.service /etc/systemd/system/udpgw@.service
        rm -rf /opt/bhttp /opt/hcr /opt/udpgw /etc/bhttp /etc/hcr /etc/hex
        rm -f /usr/local/bin/hex_menu /usr/bin/hex_menu /usr/local/bin/hex_cleanup.sh /var/log/hex-cleanup.log
        
        echo -e "  ${CYAN}Eliminando usuarios hexusers...${NC}"
        getent group "$USER_GROUP" >/dev/null 2>&1 && { for user in $(getent group "$USER_GROUP" | cut -d: -f4 | tr ',' '\n'); do userdel -r "$user" 2>/dev/null; done; groupdel "$USER_GROUP" 2>/dev/null; }
        
        crontab -l 2>/dev/null | grep -v "hex_cleanup.sh" | crontab -
        systemctl daemon-reload >/dev/null 2>&1
        
        echo ""; echo -e "  ${GREEN}✓ Desinstalado completamente${NC}"; echo ""; exit 0
    else
        echo -e "  ${YELLOW}⚠ Cancelado${NC}"; pause_return; menu_principal
    fi
}

[ "$EUID" -ne 0 ] && { echo -e "  ${RED}✗ Requiere permisos de root${NC}"; exit 1; }
menu_principal