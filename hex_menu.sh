#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  HEX MANAGER - MENÚ DE GESTIÓN
#  Repositorio: https://github.com/rogellevi/HCR_BHTTP
# ═══════════════════════════════════════════════════════════════

RED='\033[38;5;203m'
GREEN='\033[38;5;84m'
YELLOW='\033[38;5;221m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[38;5;255m'
NC='\033[0m'
BOLD='\033[1m'
ACC='\033[38;5;44m'
GRIS='\033[38;5;245m'

BHTTP_UNIT="bhttp-server.service"
HCR_UNIT="hcr-server.service"
USER_DB="/etc/hex/users.txt"
USER_GROUP="hexusers"
PORTS_CONF="/etc/hex/ports.conf"

mkdir -p /etc/hex
touch "$USER_DB"
chmod 600 "$USER_DB"

# Cargar puertos desde archivo de configuración o usar valores por defecto
if [ -f "$PORTS_CONF" ]; then
    source "$PORTS_CONF"
else
    BHTTP_PORT=80
    HCR_PORT=8080
fi

pause_return() {
    echo ""
    echo -e "  ${CYAN}Presiona ENTER para continuar...${NC}"
    read -r
}

ui_top() { echo -e "${ACC}╔════════════════════════════════════════════════════════════╗${NC}"; }
ui_sep() { echo -e "${ACC}╠════════════════════════════════════════════════════════════╣${NC}"; }
ui_bot() { echo -e "${ACC}╚════════════════════════════════════════════════════════════╝${NC}"; }
ui_fila() { echo -e "${ACC}║${NC} $1 ${ACC}║${NC}"; }
ui_titulo() { printf "${ACC}║${NC}                     ${WHITE}${BOLD}%s${NC}                     ${ACC}║${NC}\n" "$1"; }
ui_opcion() { printf "     ${CYAN}[${NC}${YELLOW}$1${NC}${CYAN}]${NC}  $2\n"; }

menu_principal() {
    clear
    ui_top
    ui_titulo "HEX MANAGER"
    ui_sep
    
    bhttp_state=$(systemctl is-active $BHTTP_UNIT 2>/dev/null || echo "inactivo")
    hcr_state=$(systemctl is-active $HCR_UNIT 2>/dev/null || echo "inactivo")
    
    [ "$bhttp_state" = "active" ] && bhttp_status="${GREEN}● ACTIVO${NC}" || bhttp_status="${RED}● INACTIVO${NC}"
    [ "$hcr_state" = "active" ] && hcr_status="${GREEN}● ACTIVO${NC}" || hcr_status="${RED}● INACTIVO${NC}"
    
    ui_fila ""
    ui_fila "  ${CYAN}BHTTP${NC} - Puerto $BHTTP_PORT  $bhttp_status"
    ui_fila "  ${CYAN}HCR${NC}   - Puerto $HCR_PORT  $hcr_status"
    ui_fila ""
    ui_sep
    
    ui_opcion "1" "Gestionar BHTTP"
    ui_opcion "2" "Gestionar HCR"
    ui_opcion "3" "Agregar usuario"
    ui_opcion "4" "Eliminar usuario"
    ui_opcion "5" "Listar usuarios activos"
    ui_opcion "6" "Configurar puertos"
    ui_opcion "7" "Ver logs"
    ui_opcion "8" "Desinstalar"
    ui_opcion "0" "Salir"
    
    ui_bot
    echo ""
    echo -ne "  ${CYAN}►${NC} Selecciona opción: "
    read -r opcion
    
    case "$opcion" in
        1) menu_bhttp ;;
        2) menu_hcr ;;
        3) agregar_usuario ;;
        4) eliminar_usuario ;;
        5) listar_usuarios ;;
        6) configurar_puertos ;;
        7) ver_logs ;;
        8) desinstalar ;;
        0) exit 0 ;;
        *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return; menu_principal ;;
    esac
}

menu_bhttp() {
    while true; do
        clear
        ui_top
        ui_titulo "GESTIÓN BHTTP"
        ui_sep
        
        bhttp_state=$(systemctl is-active $BHTTP_UNIT 2>/dev/null || echo "inactivo")
        [ "$bhttp_state" = "active" ] && bhttp_status="${GREEN}● ACTIVO${NC}" || bhttp_status="${RED}● INACTIVO${NC}"
        
        ui_fila "  Estado: $bhttp_status  │  Puerto: ${YELLOW}$BHTTP_PORT${NC}"
        ui_sep
        ui_fila ""
        
        ui_opcion "1" "Iniciar"
        ui_opcion "2" "Detener"
        ui_opcion "3" "Reiniciar"
        ui_opcion "4" "Ver estado"
        ui_opcion "0" "Atrás"
        
        ui_bot
        echo ""
        echo -ne "  ${CYAN}►${NC} Selecciona opción: "
        read -r opt
        
        case "$opt" in
            1) systemctl start $BHTTP_UNIT; echo -e "  ${GREEN}✓ BHTTP iniciado${NC}"; pause_return ;;
            2) systemctl stop $BHTTP_UNIT; echo -e "  ${GREEN}✓ BHTTP detenido${NC}"; pause_return ;;
            3) systemctl restart $BHTTP_UNIT; echo -e "  ${GREEN}✓ BHTTP reiniciado${NC}"; pause_return ;;
            4) echo ""; systemctl status $BHTTP_UNIT --no-pager; pause_return ;;
            0) break ;;
            *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
        esac
    done
    menu_principal
}

menu_hcr() {
    while true; do
        clear
        ui_top
        ui_titulo "GESTIÓN HCR"
        ui_sep
        
        hcr_state=$(systemctl is-active $HCR_UNIT 2>/dev/null || echo "inactivo")
        [ "$hcr_state" = "active" ] && hcr_status="${GREEN}● ACTIVO${NC}" || hcr_status="${RED}● INACTIVO${NC}"
        
        ui_fila "  Estado: $hcr_status  │  Puerto: ${YELLOW}$HCR_PORT${NC}"
        ui_sep
        ui_fila ""
        
        ui_opcion "1" "Iniciar"
        ui_opcion "2" "Detener"
        ui_opcion "3" "Reiniciar"
        ui_opcion "4" "Ver estado"
        ui_opcion "0" "Atrás"
        
        ui_bot
        echo ""
        echo -ne "  ${CYAN}►${NC} Selecciona opción: "
        read -r opt
        
        case "$opt" in
            1) systemctl start $HCR_UNIT; echo -e "  ${GREEN}✓ HCR iniciado${NC}"; pause_return ;;
            2) systemctl stop $HCR_UNIT; echo -e "  ${GREEN}✓ HCR detenido${NC}"; pause_return ;;
            3) systemctl restart $HCR_UNIT; echo -e "  ${GREEN}✓ HCR reiniciado${NC}"; pause_return ;;
            4) echo ""; systemctl status $HCR_UNIT --no-pager; pause_return ;;
            0) break ;;
            *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
        esac
    done
    menu_principal
}

configurar_puertos() {
    clear
    ui_top
    ui_titulo "CONFIGURAR PUERTOS"
    ui_sep
    
    ui_fila ""
    ui_fila "  ${CYAN}Puertos actuales:${NC}"
    ui_fila "  BHTTP: ${YELLOW}$BHTTP_PORT${NC}"
    ui_fila "  HCR:   ${YELLOW}$HCR_PORT${NC}"
    ui_fila ""
    ui_sep
    ui_fila ""
    
    echo -ne "  ${WHITE}Nuevo puerto BHTTP (actual: $BHTTP_PORT):${NC} "
    read -r new_bhttp_port
    
    if [ -n "$new_bhttp_port" ]; then
        if ! [[ "$new_bhttp_port" =~ ^[0-9]+$ ]] || [ "$new_bhttp_port" -lt 1 ] || [ "$new_bhttp_port" -gt 65535 ]; then
            echo -e "  ${RED}✗ Puerto inválido (debe ser entre 1 y 65535)${NC}"
            pause_return
            menu_principal
            return
        fi
        
        if ss -tuln | grep -q ":$new_bhttp_port "; then
            echo -e "  ${RED}✗ El puerto $new_bhttp_port ya está en uso${NC}"
            pause_return
            menu_principal
            return
        fi
        
        BHTTP_PORT=$new_bhttp_port
    fi
    
    echo -ne "  ${WHITE}Nuevo puerto HCR (actual: $HCR_PORT):${NC} "
    read -r new_hcr_port
    
    if [ -n "$new_hcr_port" ]; then
        if ! [[ "$new_hcr_port" =~ ^[0-9]+$ ]] || [ "$new_hcr_port" -lt 1 ] || [ "$new_hcr_port" -gt 65535 ]; then
            echo -e "  ${RED}✗ Puerto inválido (debe ser entre 1 y 65535)${NC}"
            pause_return
            menu_principal
            return
        fi
        
        if ss -tuln | grep -q ":$new_hcr_port "; then
            echo -e "  ${RED}✗ El puerto $new_hcr_port ya está en uso${NC}"
            pause_return
            menu_principal
            return
        fi
        
        HCR_PORT=$new_hcr_port
    fi
    
    echo "BHTTP_PORT=$BHTTP_PORT" > "$PORTS_CONF"
    echo "HCR_PORT=$HCR_PORT" >> "$PORTS_CONF"
    
    sed -i "s|-port [0-9]\+|-port $BHTTP_PORT|g" /etc/systemd/system/bhttp-server.service
    sed -i "s|--listen :[0-9]\+|--listen :$HCR_PORT|g" /etc/systemd/system/hcr-server.service
    
    systemctl daemon-reload >/dev/null 2>&1
    
    iptables -D INPUT -p tcp --dport $BHTTP_PORT -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport $BHTTP_PORT -j ACCEPT >/dev/null 2>&1
    command -v ufw >/dev/null 2>&1 && ufw allow $BHTTP_PORT/tcp >/dev/null 2>&1
    
    iptables -D INPUT -p tcp --dport $HCR_PORT -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport $HCR_PORT -j ACCEPT >/dev/null 2>&1
    command -v ufw >/dev/null 2>&1 && ufw allow $HCR_PORT/tcp >/dev/null 2>&1
    
    systemctl restart $BHTTP_UNIT 2>/dev/null
    systemctl restart $HCR_UNIT 2>/dev/null
    
    echo ""
    echo -e "  ${GREEN}✓ Puertos actualizados correctamente${NC}"
    echo ""
    echo -e "  ${BOLD}BHTTP:${NC} Puerto ${YELLOW}$BHTTP_PORT${NC}"
    echo -e "  ${BOLD}HCR:${NC}   Puerto ${YELLOW}$HCR_PORT${NC}"
    echo ""
    
    pause_return
    menu_principal
}

agregar_usuario() {
    clear
    ui_top
    ui_titulo "AGREGAR USUARIO"
    ui_sep
    
    if ! getent group "$USER_GROUP" >/dev/null 2>&1; then
        groupadd "$USER_GROUP" 2>/dev/null
    fi
    
    echo ""
    echo -ne "  ${WHITE}Usuario:${NC} "
    read -r new_user
    
    if ! [[ "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "  ${RED}✗ Nombre de usuario inválido (solo letras minúsculas, números, _ y -)${NC}"
        pause_return
        menu_principal
        return
    fi
    
    if id "$new_user" >/dev/null 2>&1; then
        echo -e "  ${RED}✗ El usuario ya existe en el sistema${NC}"
        pause_return
        menu_principal
        return
    fi
    
    echo -ne "  ${WHITE}Contraseña:${NC} "
    read -rs new_pass
    echo ""
    
    if [ -z "$new_pass" ]; then
        echo -e "  ${RED}✗ La contraseña no puede estar vacía${NC}"
        pause_return
        menu_principal
        return
    fi
    
    echo -ne "  ${WHITE}Validez (días):${NC} "
    read -r days
    
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -eq 0 ]; then
        echo -e "  ${RED}✗ Número de días inválido${NC}"
        pause_return
        menu_principal
        return
    fi
    
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    useradd -m -s /bin/bash -G "$USER_GROUP" "$new_user" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}✗ Error al crear el usuario en el sistema${NC}"
        pause_return
        menu_principal
        return
    fi
    
    echo "$new_user:$new_pass" | chpasswd
    chage -E "$exp_date" "$new_user"
    echo "${new_user}:${new_pass}:${exp_date}" >> "$USER_DB"
    usermod -e "$exp_date" "$new_user"
    
    echo ""
    echo -e "  ${GREEN}✓ Usuario creado exitosamente${NC}"
    echo ""
    echo -e "  ${BOLD}IP:${NC}              $(hostname -I | awk '{print $1}')"
    echo -e "  ${BOLD}BHTTP Puerto:${NC}   ${YELLOW}$BHTTP_PORT${NC}"
    echo -e "  ${BOLD}HCR Puerto:${NC}     ${YELLOW}$HCR_PORT${NC}"
    echo -e "  ${BOLD}Usuario:${NC}        ${YELLOW}${new_user}${NC}"
    echo -e "  ${BOLD}Contraseña:${NC}     ${YELLOW}${new_pass}${NC}"
    echo -e "  ${BOLD}Fecha Expiración:${NC} ${YELLOW}${exp_date}${NC}"
    echo ""
    
    pause_return
    menu_principal
}

eliminar_usuario() {
    clear
    ui_top
    ui_titulo "ELIMINAR USUARIO"
    ui_sep
    
    if [ ! -s "$USER_DB" ]; then
        echo -e "  ${YELLOW}No hay usuarios registrados${NC}"
        pause_return
        menu_principal
        return
    fi
    
    echo ""
    echo -e "  ${CYAN}Usuarios activos:${NC}"
    echo ""
    cat -n "$USER_DB" | awk -F: '{printf "    ${YELLOW}[%s]${NC} %s (Exp: %s)\n", NR, $1, $3}' | sed "s/\${YELLOW}/\x1b[38;5;221m/g; s/\${NC}/\x1b[0m/g"
    echo ""
    
    echo -ne "  ${WHITE}Usuario a eliminar:${NC} "
    read -r del_user
    
    if ! id "$del_user" >/dev/null 2>&1; then
        echo -e "  ${RED}✗ El usuario no existe en el sistema${NC}"
        pause_return
        menu_principal
        return
    fi
    
    userdel -r "$del_user" 2>/dev/null
    sed -i "/^$del_user:/d" "$USER_DB"
    
    echo -e "  ${GREEN}✓ Usuario eliminado del sistema${NC}"
    
    pause_return
    menu_principal
}

listar_usuarios() {
    clear
    ui_top
    ui_titulo "USUARIOS ACTIVOS"
    ui_sep
    
    if [ ! -s "$USER_DB" ]; then
        echo ""
        echo -e "  ${YELLOW}⚠ No hay usuarios registrados${NC}"
        echo ""
        ui_sep
        ui_fila ""
        ui_fila "  ${GRIS}Usa la opción 3 para agregar usuarios${NC}"
        ui_fila ""
        pause_return
        menu_principal
        return
    fi
    
    total_users=$(wc -l < "$USER_DB")
    active_users=0
    expired_users=0
    expiring_soon=0
    current_date=$(date +%Y-%m-%d)
    current_timestamp=$(date +%s)
    
    echo ""
    echo -e "  ${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC} ${WHITE}${BOLD}#   Usuario          Contraseña      Expira          Días Rest.  Estado${NC}          ${CYAN}║${NC}"
    echo -e "  ${CYAN}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    counter=1
    while IFS=: read -r user pass exp; do
        if id "$user" >/dev/null 2>&1; then
            exp_timestamp=$(date -d "$exp" +%s 2>/dev/null || echo "0")
            days_left=$(( (exp_timestamp - current_timestamp) / 86400 ))
            
            if [ "$exp_timestamp" -lt "$current_timestamp" ]; then
                status="${RED}● EXPIRADO${NC}"
                days_color="${RED}"
                ((expired_users++))
            elif [ "$days_left" -le 3 ]; then
                status="${YELLOW}● POR EXPIRAR${NC}"
                days_color="${YELLOW}"
                ((expiring_soon++))
            else
                status="${GREEN}● ACTIVO${NC}"
                days_color="${GREEN}"
                ((active_users++))
            fi
            
            if [ ${#pass} -gt 3 ]; then
                pass_masked="${pass:0:3}***"
            else
                pass_masked="***"
            fi
            
            printf "  ${CYAN}║${NC} ${YELLOW}%-3s${NC} ${WHITE}%-16s${NC} ${GRIS}%-15s${NC} ${WHITE}%-15s${NC} ${days_color}%-11s${NC} %b\n" \
                "$counter" "$user" "$pass_masked" "$exp" "$days_left" "$status"
            
            ((counter++))
        fi
    done < "$USER_DB"
    
    echo -e "  ${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    ui_sep
    echo ""
    echo -e "  ${BOLD}RESUMEN:${NC}"
    echo -e "  Total usuarios:     ${WHITE}$total_users${NC}"
    echo -e "  Activos:            ${GREEN}$active_users${NC}"
    echo -e "  Por expirar (≤3d):  ${YELLOW}$expiring_soon${NC}"
    echo -e "  Expirados:          ${RED}$expired_users${NC}"
    echo ""
    ui_sep
    ui_fila ""
    
    pause_return
    menu_principal
}

ver_logs() {
    clear
    ui_top
    ui_titulo "VER LOGS"
    ui_sep
    ui_fila ""
    
    ui_opcion "1" "BHTTP (últimas 50 líneas)"
    ui_opcion "2" "HCR (últimas 50 líneas)"
    ui_opcion "3" "BHTTP (todas)"
    ui_opcion "4" "HCR (todas)"
    ui_opcion "0" "Atrás"
    
    ui_bot
    echo ""
    echo -ne "  ${CYAN}►${NC} Selecciona opción: "
    read -r opt
    
    case "$opt" in
        1) echo ""; journalctl -u $BHTTP_UNIT -n 50 --no-pager; pause_return ;;
        2) echo ""; journalctl -u $HCR_UNIT -n 50 --no-pager; pause_return ;;
        3) journalctl -u $BHTTP_UNIT --no-pager | less ;;
        4) journalctl -u $HCR_UNIT --no-pager | less ;;
        0) ;;
        *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
    esac
    
    menu_principal
}

desinstalar() {
    clear
    ui_top
    ui_titulo "DESINSTALAR"
    ui_sep
    ui_fila ""
    ui_fila "  ${YELLOW}⚠${NC}  Estás a punto de desinstalar"
    ui_fila ""
    ui_sep
    
    echo ""
    echo -ne "  ${RED}✗ Escriba${NC} ${YELLOW}${BOLD}CONFIRMAR${NC} ${RED}para continuar:${NC} "
    read -r confirm
    
    if [ "$confirm" = "CONFIRMAR" ]; then
        echo -e "  ${CYAN}Deteniendo servicios...${NC}"
        systemctl stop $BHTTP_UNIT 2>/dev/null || true
        systemctl stop $HCR_UNIT 2>/dev/null || true
        
        echo -e "  ${CYAN}Deshabilitando servicios...${NC}"
        systemctl disable $BHTTP_UNIT 2>/dev/null || true
        systemctl disable $HCR_UNIT 2>/dev/null || true
        
        echo -e "  ${CYAN}Eliminando archivos...${NC}"
        rm -f /etc/systemd/system/bhttp-server.service
        rm -f /etc/systemd/system/hcr-server.service
        rm -rf /opt/bhttp
        rm -rf /opt/hcr
        rm -rf /etc/bhttp
        rm -rf /etc/hcr
        rm -rf /etc/hex
        rm -f /usr/local/bin/hex_menu
        rm -f /usr/bin/hex_menu
        
        echo -e "  ${CYAN}Eliminando usuarios del grupo hexusers...${NC}"
        if getent group "$USER_GROUP" >/dev/null 2>&1; then
            for user in $(getent group "$USER_GROUP" | cut -d: -f4 | tr ',' '\n'); do
                userdel -r "$user" 2>/dev/null
            done
            groupdel "$USER_GROUP" 2>/dev/null
        fi
        
        systemctl daemon-reload >/dev/null 2>&1
        
        echo ""
        echo -e "  ${GREEN}✓ Desinstalado completamente${NC}"
        echo ""
        exit 0
    else
        echo -e "  ${YELLOW}⚠ Cancelado${NC}"
        pause_return
        menu_principal
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo -e "  ${RED}✗ Requiere permisos de root${NC}"
    exit 1
fi

menu_principal