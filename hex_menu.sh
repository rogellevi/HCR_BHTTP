#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  HEX MANAGER - MENÚ DE GESTIÓN COMPLETO (v3.0)
#  Repositorio: https://github.com/rogellevi/HCR_BHTTP
# ═══════════════════════════════════════════════════════════════

RED='\033[38;5;203m'; GREEN='\033[38;5;84m'; YELLOW='\033[38;5;221m'
CYAN='\033[38;5;51m'; WHITE='\033[38;5;255m'; NC='\033[0m'
BOLD='\033[1m'; ACC='\033[38;5;44m'; GRIS='\033[38;5;245m'

BHTTP_PORTS_CONF="/etc/hex/bhttp_ports.conf"
HCR_PORTS_CONF="/etc/hex/hcr_ports.conf"
UDPGW_PORTS_CONF="/etc/hex/udpgw_ports.conf"
USER_DB="/etc/hex/users.txt"
USER_GROUP="hexusers"
CLEANUP_SCRIPT="/usr/local/bin/hex_cleanup.sh"
CLEANUP_LOG="/var/log/hex-cleanup.log"
WEBPANEL_SERVICE="hex-webpanel.service"

mkdir -p /etc/hex
touch "$USER_DB" && chmod 600 "$USER_DB"
[ -f "$BHTTP_PORTS_CONF" ] || echo "80" > "$BHTTP_PORTS_CONF"
[ -f "$HCR_PORTS_CONF" ] || echo "8080" > "$HCR_PORTS_CONF"
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

# ═══════════════════════════════════════════════════════════════
#  FUNCIONES DE INTERFAZ DE USUARIO (UI)
# ═══════════════════════════════════════════════════════════════
pause_return() { echo ""; echo -e "  ${CYAN}Presiona ENTER para continuar...${NC}"; read -r; }
ui_top() { echo -e "${ACC}╔════════════════════════════════════════════════════════════╗${NC}"; }
ui_sep() { echo -e "${ACC}╠════════════════════════════════════════════════════════════╣${NC}"; }
ui_bot() { echo -e "${ACC}╚════════════════════════════════════════════════════════════╝${NC}"; }
ui_fila() { echo -e "${ACC}║${NC} $1 ${ACC}║${NC}"; }
ui_titulo() { printf "${ACC}║${NC}                     ${WHITE}${BOLD}%s${NC}                     ${ACC}║${NC}\n" "$1"; }
ui_opcion() { printf "     ${CYAN}[${NC}${YELLOW}$1${NC}${CYAN}]${NC}  $2\n"; }
ui_info() { echo -e "     ${CYAN}ℹ${NC} ${GRIS}$1${NC}"; }
ui_ok() { echo -e "     ${GREEN}✓${NC} ${WHITE}$1${NC}"; }
ui_error() { echo -e "     ${RED}✗${NC} ${RED}$1${NC}"; }

get_svc_status() {
    local svc=$1 conf=$2
    local total=0 active=0
    if [ -f "$conf" ]; then
        while read -r port; do
            [ -z "$port" ] && continue; ((total++))
            systemctl is-active --quiet "${svc}@${port}.service" 2>/dev/null && ((active++))
        done < "$conf"
    fi
    if [ "$total" -eq 0 ]; then echo "${RED}● SIN PUERTOS${NC} (0)"
    elif [ "$active" -eq "$total" ]; then echo "${GREEN}● ACTIVO${NC} ($active/$total)"
    elif [ "$active" -gt 0 ]; then echo "${YELLOW}● PARCIAL${NC} ($active/$total)"
    else echo "${RED}● INACTIVO${NC} (0/$total)"; fi
}

menu_principal() {
    clear; ui_top; ui_titulo "HEX MANAGER"; ui_sep
    
    bhttp_st=$(get_svc_status "bhttp" "$BHTTP_PORTS_CONF")
    hcr_st=$(get_svc_status "hcr" "$HCR_PORTS_CONF")
    udpgw_st=$(get_svc_status "udpgw" "$UDPGW_PORTS_CONF")
    [ "$cron_active" -gt 0 ] && cleanup_status="${GREEN}● ACTIVO${NC}" || cleanup_status="${RED}● INACTIVO${NC}"
    
    webpanel_state=$(systemctl is-active $WEBPANEL_SERVICE 2>/dev/null || echo "inactivo")
    [ -f "/opt/hex-webpanel/app.py" ] && [ "$webpanel_state" = "active" ] && webpanel_status="${GREEN}● ACTIVO${NC}" || webpanel_status="${RED}● INACTIVO${NC}"
    [ ! -f "/opt/hex-webpanel/app.py" ] && webpanel_status="${YELLOW}● NO INSTALADO${NC}"
    
    ui_fila ""
    ui_fila "  ${CYAN}BHTTP${NC}     - $bhttp_st"
    ui_fila "  ${CYAN}HCR${NC}       - $hcr_st"
    ui_fila "  ${CYAN}UDPGW${NC}     - $udpgw_st"
    ui_fila "  ${CYAN}WEB PANEL${NC} - Puerto 9000     $webpanel_status"
    ui_fila "  ${CYAN}LIMPIADOR${NC} - Diario 03:00    $cleanup_status"
    ui_fila ""; ui_sep
    
    ui_opcion "1" "Gestionar BHTTP"
    ui_opcion "2" "Gestionar HCR"
    ui_opcion "3" "Gestionar UDPGW"
    ui_opcion "4" "Gestionar Panel Web"
    ui_opcion "5" "Agregar usuario"
    ui_opcion "6" "Eliminar usuario"
    ui_opcion "7" "Listar usuarios activos"
    ui_opcion "8" "Limpieza automática"
    ui_opcion "9" "Ver logs"
    ui_opcion "10" "Desinstalar todo"
    ui_opcion "0" "Salir"
    
    ui_bot; echo ""
    echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opcion
    
    case "$opcion" in
        1) menu_generico "bhttp" "BHTTP" "$BHTTP_PORTS_CONF" "tcp" ;;
        2) menu_generico "hcr" "HCR" "$HCR_PORTS_CONF" "tcp" ;;
        3) menu_generico "udpgw" "UDPGW" "$UDPGW_PORTS_CONF" "udp" ;;
        4) gestionar_webpanel ;;
        5) agregar_usuario ;; 6) eliminar_usuario ;; 7) listar_usuarios ;;
        8) gestionar_limpieza ;; 9) ver_logs ;; 10) desinstalar ;; 0) exit 0 ;;
        *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return; menu_principal ;;
    esac
}

menu_generico() {
    local svc=$1 title=$2 conf=$3 proto=$4
    while true; do
        clear; ui_top; ui_titulo "GESTIÓN $title"; ui_sep; echo ""
        echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${CYAN}║${NC}  ${WHITE}${BOLD}Puerto     Estado              Protocolo${NC}                 ${CYAN}║${NC}"
        echo -e "  ${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        
        count=0
        if [ -f "$conf" ]; then
            while read -r port; do
                [ -z "$port" ] && continue; ((count++))
                systemctl is-active --quiet "${svc}@${port}.service" 2>/dev/null && status="${GREEN}● ACTIVO${NC}    " || status="${RED}● INACTIVO${NC}  "
                printf "  ${CYAN}║${NC}  ${YELLOW}%-10s${NC} %b  ${GRIS}%s${NC}                     ${CYAN}║${NC}\n" "$port" "$status" "$proto"
            done < "$conf"
        fi
        [ "$count" -eq 0 ] && echo -e "  ${CYAN}║${NC}  ${YELLOW}No hay puertos configurados${NC}                            ${CYAN}║${NC}"
        echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"; echo ""
        ui_sep; ui_fila ""
        
        ui_opcion "1" "Agregar puerto"
        ui_opcion "2" "Eliminar puerto"
        ui_opcion "3" "Iniciar todos"
        ui_opcion "4" "Detener todos"
        ui_opcion "5" "Reiniciar todos"
        ui_opcion "6" "Control individual"
        ui_opcion "0" "Atrás"
        ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
        
        case "$opt" in
            1) generic_add_port "$svc" "$title" "$conf" "$proto" ;;
            2) generic_del_port "$svc" "$title" "$conf" "$proto" ;;
            3) generic_action_all "$svc" "$conf" "start" "iniciado"; pause_return ;;
            4) generic_action_all "$svc" "$conf" "stop" "detenido"; pause_return ;;
            5) generic_action_all "$svc" "$conf" "restart" "reiniciado"; pause_return ;;
            6) generic_control_individual "$svc" "$conf"; pause_return ;;
            0) break ;; *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
        esac
    done
    menu_principal
}

generic_add_port() {
    local svc=$1 title=$2 conf=$3 proto=$4
    clear; ui_top; ui_titulo "AGREGAR PUERTO $title"; ui_sep; ui_fila ""
    echo -ne "  ${WHITE}Número de puerto:${NC} "; read -r new_port
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "  ${RED}✗ Puerto inválido${NC}"; pause_return; return
    fi
    grep -qw "^$new_port$" "$conf" 2>/dev/null && { echo -e "  ${RED}✗ El puerto ya está configurado${NC}"; pause_return; return; }
    ss -tuln | grep -q ":$new_port " && { echo -e "  ${RED}✗ El puerto ya está en uso${NC}"; pause_return; return; }
    
    echo "$new_port" >> "$conf"
    iptables -I INPUT -p $proto --dport $new_port -j ACCEPT 2>/dev/null
    [ "$proto" == "udp" ] && iptables -I INPUT -p tcp --dport $new_port -j ACCEPT 2>/dev/null
    command -v ufw >/dev/null 2>&1 && { ufw allow $new_port/$proto >/dev/null 2>&1; [ "$proto" == "udp" ] && ufw allow $new_port/tcp >/dev/null 2>&1; }
    
    systemctl enable "${svc}@${new_port}.service" >/dev/null 2>&1
    systemctl start "${svc}@${new_port}.service" 2>/dev/null
    sleep 1
    systemctl is-active --quiet "${svc}@${new_port}.service" 2>/dev/null && echo -e "  ${GREEN}✓ Puerto $new_port agregado y activo${NC}" || echo -e "  ${YELLOW}⚠ Puerto agregado pero no inició${NC}"
    pause_return
}

generic_del_port() {
    local svc=$1 title=$2 conf=$3 proto=$4
    clear; ui_top; ui_titulo "ELIMINAR PUERTO $title"; ui_sep; ui_fila ""
    [ ! -s "$conf" ] && { echo -e "  ${YELLOW}No hay puertos configurados${NC}"; pause_return; return; }
    
    echo -e "  ${CYAN}Puertos actuales:${NC}"; echo ""
    counter=1
    while read -r port; do
        [ -z "$port" ] && continue
        systemctl is-active --quiet "${svc}@${port}.service" 2>/dev/null && status="${GREEN}● ACTIVO${NC}" || status="${RED}● INACTIVO${NC}"
        printf "    ${YELLOW}[%s]${NC} Puerto ${WHITE}%s${NC}  %b\n" "$counter" "$port" "$status"; ((counter++))
    done < "$conf"
    echo ""
    
    echo -ne "  ${WHITE}Número de puerto a eliminar:${NC} "; read -r del_port
    grep -qw "^$del_port$" "$conf" || { echo -e "  ${RED}✗ El puerto no existe${NC}"; pause_return; return; }
    
    systemctl stop "${svc}@${del_port}.service" 2>/dev/null
    systemctl disable "${svc}@${del_port}.service" 2>/dev/null
    sed -i "/^${del_port}$/d" "$conf"
    iptables -D INPUT -p $proto --dport $del_port -j ACCEPT 2>/dev/null
    [ "$proto" == "udp" ] && iptables -D INPUT -p tcp --dport $del_port -j ACCEPT 2>/dev/null
    command -v ufw >/dev/null 2>&1 && { ufw delete allow $del_port/$proto >/dev/null 2>&1; [ "$proto" == "udp" ] && ufw delete allow $del_port/tcp >/dev/null 2>&1; }
    
    echo -e "  ${GREEN}✓ Puerto $del_port eliminado completamente${NC}"; pause_return
}

generic_action_all() {
    local svc=$1 conf=$2 action=$3 msg=$4
    echo -e "  ${CYAN}${action^}ing todos los puertos $svc...${NC}"
    [ -f "$conf" ] && while read -r port; do 
        [ -z "$port" ] && continue
        systemctl $action "${svc}@${port}.service" 2>/dev/null
        echo -e "  ${GREEN}✓ Puerto $port $msg${NC}"
    done < "$conf"
}

generic_control_individual() {
    local svc=$1 conf=$2
    clear; ui_top; ui_titulo "CONTROL INDIVIDUAL"; ui_sep; ui_fila ""
    echo -e "  ${CYAN}Puertos disponibles:${NC}"; echo ""
    counter=1
    while read -r port; do
        [ -z "$port" ] && continue
        systemctl is-active --quiet "${svc}@${port}.service" 2>/dev/null && status="${GREEN}● ACTIVO${NC}" || status="${RED}● INACTIVO${NC}"
        printf "    ${YELLOW}[%s]${NC} Puerto ${WHITE}%s${NC}  %b\n" "$counter" "$port" "$status"; ((counter++))
    done < "$conf"
    echo ""; echo -ne "  ${WHITE}Número de puerto:${NC} "; read -r target_port
    grep -qw "^$target_port$" "$conf" || { echo -e "  ${RED}✗ Puerto no encontrado${NC}"; return; }
    
    echo ""; echo -e "  ${CYAN}Acciones para puerto $target_port:${NC}"; echo ""
    ui_opcion "1" "Iniciar"; ui_opcion "2" "Detener"; ui_opcion "3" "Reiniciar"; ui_opcion "4" "Ver estado"; ui_opcion "0" "Cancelar"
    echo ""; echo -ne "  ${CYAN}►${NC} Opción: "; read -r action
    case "$action" in
        1) systemctl start "${svc}@${target_port}.service"; echo -e "  ${GREEN}✓ Iniciado${NC}" ;;
        2) systemctl stop "${svc}@${target_port}.service"; echo -e "  ${GREEN}✓ Detenido${NC}" ;;
        3) systemctl restart "${svc}@${target_port}.service"; echo -e "  ${GREEN}✓ Reiniciado${NC}" ;;
        4) systemctl status "${svc}@${target_port}.service" --no-pager ;;
        0) return ;; *) echo -e "  ${RED}✗ Opción inválida${NC}" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
#  INSTALACIÓN AUTOMÁTICA DEL PANEL WEB (CON DISEÑO MODERNO)
# ═══════════════════════════════════════════════════════════════

instalar_panel_web_automatico() {
    clear; ui_top; ui_titulo "INSTALANDO PANEL WEB"; ui_sep; ui_fila ""
    ui_info "Este proceso puede tomar unos minutos..."
    ui_info "Instalando dependencias de Python..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y python3 python3-pip python3-venv >/dev/null 2>&1
    
    ui_info "Creando entorno virtual..."
    mkdir -p /opt/hex-webpanel/templates
    cd /opt/hex-webpanel || return
    python3 -m venv venv >/dev/null 2>&1
    source venv/bin/activate
    pip install flask flask-login psutil >/dev/null 2>&1
    
    ui_info "Creando archivos de la aplicación..."
    
    cat > /opt/hex-webpanel/app.py <<'EOF_APP'
import os, subprocess, datetime, logging
from flask import Flask, render_template, request, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user

logging.basicConfig(filename='/var/log/hex-webpanel.log', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)
app.secret_key = 'hex_secret_key_cambiar_123'
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
ADMIN_PASSWORD = "HexAdmin2026"

SYSTEMCTL = '/usr/bin/systemctl'
USERADD = '/usr/sbin/useradd'
USERDEL = '/usr/sbin/userdel'
USERMOD = '/usr/sbin/usermod'
CHPASSWD = '/usr/sbin/chpasswd'
CHAGE = '/usr/bin/chage'
GROUPADD = '/usr/sbin/groupadd'
ID = '/usr/bin/id'
GETENT = '/usr/bin/getent'

class User(UserMixin):
    def __init__(self, id): self.id = id

@login_manager.user_loader
def load_user(user_id): return User(user_id)

def get_service_status(svc, port):
    try:
        result = subprocess.run([SYSTEMCTL, 'is-active', f"{svc}@{port}.service"], 
                              capture_output=True, text=True)
        return result.returncode == 0 and "active" in result.stdout
    except: return False

def get_users():
    users = []
    if os.path.exists("/etc/hex/users.txt"):
        try:
            with open("/etc/hex/users.txt", "r") as f:
                for line in f:
                    parts = line.strip().split(":")
                    if len(parts) == 3: 
                        users.append({"user": parts[0], "exp": parts[2]})
        except Exception as e:
            logging.error(f"Error leyendo users.txt: {e}")
    return users

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form['password'] == ADMIN_PASSWORD:
            login_user(User("admin"))
            return redirect(url_for('dashboard'))
        flash('Contraseña incorrecta')
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout(): 
    logout_user()
    return redirect(url_for('login'))

@app.route('/')
@login_required
def dashboard():
    try:
        bhttp_ports = open("/etc/hex/bhttp_ports.conf").read().splitlines() if os.path.exists("/etc/hex/bhttp_ports.conf") else []
        hcr_ports = open("/etc/hex/hcr_ports.conf").read().splitlines() if os.path.exists("/etc/hex/hcr_ports.conf") else []
        udpgw_ports = open("/etc/hex/udpgw_ports.conf").read().splitlines() if os.path.exists("/etc/hex/udpgw_ports.conf") else []
        
        stats = {
            "bhttp_ports": [p for p in bhttp_ports if p.strip()],
            "hcr_ports": [p for p in hcr_ports if p.strip()],
            "udpgw_ports": [p for p in udpgw_ports if p.strip()],
            "bhttp_active": sum(1 for p in bhttp_ports if get_service_status("bhttp", p)),
            "hcr_active": sum(1 for p in hcr_ports if get_service_status("hcr", p)),
            "udpgw_active": sum(1 for p in udpgw_ports if get_service_status("udpgw", p)),
            "users": len(get_users())
        }
        return render_template('dashboard.html', stats=stats, users=get_users())
    except Exception as e:
        logging.error(f"Error en dashboard: {e}")
        flash(f"Error al cargar dashboard: {str(e)}")
        return render_template('dashboard.html', stats={"bhttp_ports":[], "hcr_ports":[], "udpgw_ports":[], "bhttp_active":0, "hcr_active":0, "udpgw_active":0, "users":0}, users=[])

@app.route('/add_user', methods=['POST'])
@login_required
def add_user():
    try:
        user = request.form['username'].strip().lower()
        pwd = request.form['password']
        days = int(request.form['days'])
        
        if not user or not pwd or days < 1:
            flash("Todos los campos son obligatorios y los días deben ser positivos")
            return redirect(url_for('dashboard'))
            
        if not user.isalnum() and not all(c.isalnum() or c in '_-' for c in user):
            flash("El usuario solo puede contener letras, números, guiones y guiones bajos")
            return redirect(url_for('dashboard'))
        
        check_user = subprocess.run([ID, user], capture_output=True, text=True)
        if check_user.returncode == 0:
            flash(f"El usuario '{user}' ya existe en el sistema")
            return redirect(url_for('dashboard'))
        
        check_group = subprocess.run([GETENT, 'group', 'hexusers'], capture_output=True, text=True)
        if check_group.returncode != 0:
            subprocess.run([GROUPADD, 'hexusers'], capture_output=True)
        
        exp_date = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime("%Y-%m-%d")
        
        res = subprocess.run([USERADD, '-m', '-s', '/bin/bash', '-G', 'hexusers', user], 
                           capture_output=True, text=True)
        if res.returncode != 0:
            logging.error(f"Error creando usuario: {res.stderr}")
            flash(f"Error al crear usuario: {res.stderr}")
            return redirect(url_for('dashboard'))
        
        res_pwd = subprocess.run([CHPASSWD], input=f"{user}:{pwd}", 
                                text=True, capture_output=True)
        if res_pwd.returncode != 0:
            logging.error(f"Error estableciendo contraseña: {res_pwd.stderr}")
            flash(f"Error al establecer contraseña: {res_pwd.stderr}")
            subprocess.run([USERDEL, '-r', user], capture_output=True)
            return redirect(url_for('dashboard'))
        
        subprocess.run([CHAGE, '-E', exp_date, user], capture_output=True)
        subprocess.run([USERMOD, '-e', exp_date, user], capture_output=True)
        
        with open("/etc/hex/users.txt", "a") as f: 
            f.write(f"{user}:{pwd}:{exp_date}\n")
        
        logging.info(f"Usuario creado: {user}, expira: {exp_date}")
        flash(f"✓ Usuario '{user}' creado exitosamente (Expira: {exp_date})")
        return redirect(url_for('dashboard'))
        
    except ValueError:
        flash("Error: Los días deben ser un número válido")
        return redirect(url_for('dashboard'))
    except Exception as e:
        logging.error(f"Error inesperado creando usuario: {str(e)}", exc_info=True)
        flash(f"Error inesperado: {str(e)}")
        return redirect(url_for('dashboard'))

@app.route('/delete_user/<username>')
@login_required
def delete_user(username):
    try:
        subprocess.run([USERDEL, '-r', username], capture_output=True)
        
        if os.path.exists("/etc/hex/users.txt"):
            with open("/etc/hex/users.txt", "r") as f:
                lines = f.readlines()
            with open("/etc/hex/users.txt", "w") as f:
                for line in lines:
                    if not line.startswith(f"{username}:"):
                        f.write(line)
        
        logging.info(f"Usuario eliminado: {username}")
        flash(f"✓ Usuario '{username}' eliminado correctamente")
    except Exception as e:
        logging.error(f"Error eliminando usuario {username}: {e}")
        flash(f"Error al eliminar usuario: {str(e)}")
    
    return redirect(url_for('dashboard'))

@app.route('/control_service/<svc>/<action>')
@login_required
def control_service(svc, action):
    try:
        if svc not in ['bhttp', 'hcr', 'udpgw']:
            flash(f"Servicio inválido: {svc}")
            return redirect(url_for('dashboard'))
        
        if action not in ['start', 'stop', 'restart']:
            flash(f"Acción inválida: {action}")
            return redirect(url_for('dashboard'))
        
        conf_file = f"/etc/hex/{svc}_ports.conf"
        if not os.path.exists(conf_file):
            flash(f"No hay puertos configurados para {svc.upper()}")
            return redirect(url_for('dashboard'))
        
        with open(conf_file, 'r') as f:
            ports = [p.strip() for p in f.readlines() if p.strip()]
        
        if not ports:
            flash(f"No hay puertos configurados para {svc.upper()}")
            return redirect(url_for('dashboard'))
        
        success_count = 0
        error_count = 0
        
        for port in ports:
            service_name = f"{svc}@{port}.service"
            result = subprocess.run([SYSTEMCTL, action, service_name], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                success_count += 1
            else:
                error_count += 1
                logging.error(f"Error en {action} {service_name}: {result.stderr}")
        
        if error_count == 0:
            flash(f"✓ {svc.upper()}: {action.capitalize()} exitoso en {success_count} puerto(s)")
        else:
            flash(f"⚠ {svc.upper()}: {success_count} exitoso(s), {error_count} error(es)")
        
        logging.info(f"Acción {action} en {svc}: {success_count} exitosos, {error_count} errores")
        
    except Exception as e:
        logging.error(f"Error controlando servicio {svc}: {e}")
        flash(f"Error al controlar servicio: {str(e)}")
    
    return redirect(url_for('dashboard'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=False)
EOF_APP

    ui_info "Creando interfaz web moderna..."
    
    cat > /opt/hex-webpanel/templates/login.html <<'EOF_LOGIN'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hex Panel - Acceso</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(-45deg, #0a0a0a, #1a1a2e, #16213e, #0f3460);
            background-size: 400% 400%;
            animation: gradientBG 15s ease infinite;
            font-family: 'Segoe UI', system-ui, sans-serif;
            padding: 20px;
            overflow-x: hidden;
        }
        @keyframes gradientBG {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }
        .login-card {
            background: rgba(30, 30, 46, 0.7);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            padding: 40px 35px;
            width: 100%;
            max-width: 400px;
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
            animation: slideIn 0.6s ease-out;
        }
        @keyframes slideIn {
            from { opacity: 0; transform: translateY(-30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .logo-container { text-align: center; margin-bottom: 30px; }
        .logo-hex {
            width: 80px; height: 80px; margin: 0 auto 15px;
            background: linear-gradient(135deg, #00c853, #00e676);
            clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%);
            display: flex; align-items: center; justify-content: center;
            animation: pulse 2s ease-in-out infinite;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(0, 200, 83, 0.7); }
            50% { transform: scale(1.05); box-shadow: 0 0 30px 10px rgba(0, 200, 83, 0); }
        }
        .logo-hex i { font-size: 40px; color: #fff; }
        .title { color: #fff; font-size: 28px; font-weight: 700; margin-bottom: 5px; }
        .subtitle { color: #8b8b9e; font-size: 14px; }
        .form-floating > .form-control {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            color: #fff; border-radius: 12px; height: 58px;
            padding: 1rem .75rem; transition: all 0.3s ease;
        }
        .form-floating > .form-control:focus {
            background: rgba(255, 255, 255, 0.08);
            border-color: #00c853;
            box-shadow: 0 0 0 3px rgba(0, 200, 83, 0.2);
            color: #fff;
        }
        .form-floating > label { color: #8b8b9e; padding: 1rem .75rem; }
        .form-floating > .form-control:focus ~ label,
        .form-floating > .form-control:not(:placeholder-shown) ~ label { color: #00c853; }
        .btn-login {
            background: linear-gradient(135deg, #00c853, #00e676);
            border: none; color: #fff; font-weight: 600;
            padding: 14px; border-radius: 12px; width: 100%;
            font-size: 16px; transition: all 0.3s ease; margin-top: 10px;
        }
        .btn-login:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(0, 200, 83, 0.4);
            color: #fff;
        }
        .btn-login:active { transform: translateY(0); }
        .alert-error {
            background: rgba(255, 82, 82, 0.15);
            border: 1px solid rgba(255, 82, 82, 0.3);
            color: #ff6b6b; border-radius: 12px;
            padding: 12px 15px; margin-bottom: 20px;
            font-size: 14px; text-align: center;
            animation: shake 0.5s ease-in-out;
        }
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-10px); }
            75% { transform: translateX(10px); }
        }
        .footer-text { text-align: center; color: #5a5a6e; font-size: 12px; margin-top: 25px; }
        .input-icon {
            position: absolute; right: 15px; top: 50%;
            transform: translateY(-50%); color: #5a5a6e;
            z-index: 5; pointer-events: none;
        }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="logo-container">
            <div class="logo-hex"><i class="bi bi-hexagon-fill"></i></div>
            <h1 class="title">Hex Panel</h1>
            <p class="subtitle">Panel de Administración</p>
        </div>
        {% with messages = get_flashed_messages() %}
          {% if messages %}
            <div class="alert-error">
                <i class="bi bi-exclamation-triangle-fill"></i> {{ messages[0] }}
            </div>
          {% endif %}
        {% endwith %}
        <form method="POST">
            <div class="form-floating mb-3 position-relative">
                <input type="password" class="form-control" id="password" name="password" placeholder="Contraseña" required autofocus>
                <label for="password"><i class="bi bi-lock-fill me-2"></i>Contraseña</label>
                <i class="bi bi-key-fill input-icon"></i>
            </div>
            <button type="submit" class="btn btn-login">
                <i class="bi bi-box-arrow-in-right me-2"></i>Iniciar Sesión
            </button>
        </form>
        <p class="footer-text"><i class="bi bi-shield-lock-fill"></i> Acceso restringido · v3.0</p>
    </div>
</body>
</html>
EOF_LOGIN

    cat > /opt/hex-webpanel/templates/dashboard.html <<'EOF_DASH'
<!DOCTYPE html>
<html lang="es" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hex Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <style>
        body { background-color: #121212; color: #e0e0e0; }
        .card { background-color: #1e1e1e; border: 1px solid #333; transition: transform 0.2s ease; }
        .card:hover { transform: translateY(-2px); }
        .text-success { color: #00c853 !important; }
        .alert { position: relative; z-index: 1000; }
        .btn-add-user {
            background: linear-gradient(135deg, #00c853, #00e676);
            border: none; color: #fff; font-weight: 600;
            padding: 12px 24px; border-radius: 10px;
            transition: all 0.3s ease;
        }
        .btn-add-user:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0, 200, 83, 0.4);
            color: #fff;
        }
        .modal-content { background: #1e1e1e; border: 1px solid #333; border-radius: 15px; }
        .modal-header {
            border-bottom: 1px solid #333;
            background: linear-gradient(135deg, rgba(0, 200, 83, 0.1), transparent);
            border-radius: 15px 15px 0 0;
        }
        .modal-title { color: #00c853; font-weight: 600; }
        .modal-body .form-control {
            background: #121212; border: 1px solid #333;
            color: #e0e0e0; border-radius: 8px;
        }
        .modal-body .form-control:focus {
            border-color: #00c853;
            box-shadow: 0 0 0 3px rgba(0, 200, 83, 0.2);
            background: #121212; color: #e0e0e0;
        }
        .modal-body label { color: #8b8b9e; font-size: 13px; font-weight: 500; }
        .btn-close-white { filter: invert(1); }
        .service-icon {
            width: 40px; height: 40px; border-radius: 10px;
            display: inline-flex; align-items: center; justify-content: center;
            margin-right: 10px; font-size: 20px;
        }
        .icon-bhttp { background: rgba(0, 200, 83, 0.15); color: #00c853; }
        .icon-hcr { background: rgba(0, 188, 212, 0.15); color: #00bcd4; }
        .icon-udpgw { background: rgba(255, 193, 7, 0.15); color: #ffc107; }
    </style>
</head>
<body>
    <nav class="navbar navbar-dark bg-dark border-bottom border-secondary sticky-top">
        <div class="container-fluid">
            <span class="navbar-brand mb-0 h1"><i class="bi bi-hexagon-fill text-success"></i> Hex Web Panel</span>
            <a href="/logout" class="btn btn-outline-danger btn-sm"><i class="bi bi-box-arrow-right"></i> Salir</a>
        </div>
    </nav>

    <div class="container mt-3 mt-md-4">
        {% with messages = get_flashed_messages() %}
          {% if messages %}
            {% for msg in messages %}
              <div class="alert alert-{% if 'error' in msg.lower() or '⚠' in msg %}warning{% else %}success{% endif %} alert-dismissible fade show" role="alert">
                {{ msg }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
              </div>
            {% endfor %}
          {% endif %}
        {% endwith %}

        <h5 class="mb-3"><i class="bi bi-hdd-network"></i> Servicios Activos</h5>
        <div class="row g-3 mb-4">
            <div class="col-12 col-md-6 col-lg-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <h5 class="card-title mb-0 d-flex align-items-center">
                                <span class="service-icon icon-bhttp"><i class="bi bi-globe"></i></span>
                                <span class="text-success">BHTTP</span>
                            </h5>
                            <span class="badge bg-success">{{ stats.bhttp_active }}/{{ stats.bhttp_ports|length }}</span>
                        </div>
                        <div class="mb-3">
                            <small class="text-muted">Puertos:</small>
                            <div class="d-flex flex-wrap gap-1 mt-1">
                                {% for p in stats.bhttp_ports %}<span class="badge bg-secondary">{{ p }}</span>{% else %}<span class="text-muted small">Ninguno</span>{% endfor %}
                            </div>
                        </div>
                        <div class="d-flex gap-2">
                            <a href="/control_service/bhttp/start" class="btn btn-sm btn-outline-success flex-fill" onclick="return confirm('¿Iniciar BHTTP?')"><i class="bi bi-play-fill"></i> Iniciar</a>
                            <a href="/control_service/bhttp/stop" class="btn btn-sm btn-outline-warning flex-fill" onclick="return confirm('¿Detener BHTTP?')"><i class="bi bi-stop-fill"></i> Detener</a>
                            <a href="/control_service/bhttp/restart" class="btn btn-sm btn-outline-info flex-fill" onclick="return confirm('¿Reiniciar BHTTP?')"><i class="bi bi-arrow-clockwise"></i></a>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-md-6 col-lg-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <h5 class="card-title mb-0 d-flex align-items-center">
                                <span class="service-icon icon-hcr"><i class="bi bi-shield-lock"></i></span>
                                <span class="text-info">HCR</span>
                            </h5>
                            <span class="badge bg-info text-dark">{{ stats.hcr_active }}/{{ stats.hcr_ports|length }}</span>
                        </div>
                        <div class="mb-3">
                            <small class="text-muted">Puertos:</small>
                            <div class="d-flex flex-wrap gap-1 mt-1">
                                {% for p in stats.hcr_ports %}<span class="badge bg-secondary">{{ p }}</span>{% else %}<span class="text-muted small">Ninguno</span>{% endfor %}
                            </div>
                        </div>
                        <div class="d-flex gap-2">
                            <a href="/control_service/hcr/start" class="btn btn-sm btn-outline-success flex-fill" onclick="return confirm('¿Iniciar HCR?')"><i class="bi bi-play-fill"></i> Iniciar</a>
                            <a href="/control_service/hcr/stop" class="btn btn-sm btn-outline-warning flex-fill" onclick="return confirm('¿Detener HCR?')"><i class="bi bi-stop-fill"></i> Detener</a>
                            <a href="/control_service/hcr/restart" class="btn btn-sm btn-outline-info flex-fill" onclick="return confirm('¿Reiniciar HCR?')"><i class="bi bi-arrow-clockwise"></i></a>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-md-6 col-lg-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <h5 class="card-title mb-0 d-flex align-items-center">
                                <span class="service-icon icon-udpgw"><i class="bi bi-wifi"></i></span>
                                <span class="text-warning">UDPGW</span>
                            </h5>
                            <span class="badge bg-warning text-dark">{{ stats.udpgw_active }}/{{ stats.udpgw_ports|length }}</span>
                        </div>
                        <div class="mb-3">
                            <small class="text-muted">Puertos:</small>
                            <div class="d-flex flex-wrap gap-1 mt-1">
                                {% for p in stats.udpgw_ports %}<span class="badge bg-secondary">{{ p }}</span>{% else %}<span class="text-muted small">Ninguno</span>{% endfor %}
                            </div>
                        </div>
                        <div class="d-flex gap-2">
                            <a href="/control_service/udpgw/start" class="btn btn-sm btn-outline-success flex-fill" onclick="return confirm('¿Iniciar UDPGW?')"><i class="bi bi-play-fill"></i> Iniciar</a>
                            <a href="/control_service/udpgw/stop" class="btn btn-sm btn-outline-warning flex-fill" onclick="return confirm('¿Detener UDPGW?')"><i class="bi bi-stop-fill"></i> Detener</a>
                            <a href="/control_service/udpgw/restart" class="btn btn-sm btn-outline-info flex-fill" onclick="return confirm('¿Reiniciar UDPGW?')"><i class="bi bi-arrow-clockwise"></i></a>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3">
            <div class="col-12">
                <div class="card">
                    <div class="card-body">
                        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-start align-items-sm-center mb-3 gap-2">
                            <h5 class="card-title mb-0">
                                <i class="bi bi-people-fill text-success"></i> Usuarios Activos 
                                <span class="badge bg-secondary ms-1">{{ stats.users }}</span>
                            </h5>
                            <button type="button" class="btn btn-add-user" data-bs-toggle="modal" data-bs-target="#addUserModal">
                                <i class="bi bi-person-plus-fill me-1"></i> Agregar Usuario
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-dark table-hover table-sm align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th><i class="bi bi-person-circle"></i> Usuario</th>
                                        <th><i class="bi bi-calendar-event"></i> Expiración</th>
                                        <th class="text-end"><i class="bi bi-gear"></i> Acción</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {% for u in users %}
                                    <tr>
                                        <td><strong>{{ u.user }}</strong></td>
                                        <td><span class="badge bg-secondary">{{ u.exp }}</span></td>
                                        <td class="text-end">
                                            <a href="/delete_user/{{ u.user }}" class="btn btn-sm btn-danger" onclick="return confirm('¿Eliminar a {{ u.user }}?');">
                                                <i class="bi bi-trash"></i> <span class="d-none d-sm-inline">Eliminar</span>
                                            </a>
                                        </td>
                                    </tr>
                                    {% else %}
                                    <tr><td colspan="3" class="text-center text-muted py-4">
                                        <i class="bi bi-inbox" style="font-size: 2rem;"></i><br>
                                        No hay usuarios registrados. Haz clic en "Agregar Usuario" para comenzar.
                                    </td></tr>
                                    {% endfor %}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="modal fade" id="addUserModal" tabindex="-1" aria-labelledby="addUserModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="addUserModalLabel">
                        <i class="bi bi-person-plus-fill"></i> Crear Nuevo Usuario
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <form action="/add_user" method="POST" id="addUserForm">
                    <div class="modal-body">
                        <div class="mb-3">
                            <label for="username" class="form-label"><i class="bi bi-person"></i> Nombre de usuario</label>
                            <input type="text" class="form-control" id="username" name="username" 
                                   placeholder="ej: juan_perez" required pattern="[a-z0-9_-]+" 
                                   title="Solo letras minúsculas, números, guiones y guiones bajos"
                                   autocomplete="off">
                            <small class="text-muted">Solo minúsculas, números, _ y -</small>
                        </div>
                        <div class="mb-3">
                            <label for="password" class="form-label"><i class="bi bi-key"></i> Contraseña</label>
                            <input type="text" class="form-control" id="password" name="password" 
                                   placeholder="Contraseña segura" required autocomplete="off">
                        </div>
                        <div class="mb-3">
                            <label for="days" class="form-label"><i class="bi bi-calendar3"></i> Días de validez</label>
                            <input type="number" class="form-control" id="days" name="days" 
                                   placeholder="30" min="1" value="30" required>
                            <small class="text-muted">El usuario expirará automáticamente después de estos días</small>
                        </div>
                        <div class="alert alert-info border-0 mb-0" style="background: rgba(0, 188, 212, 0.1); color: #4dd0e1;">
                            <i class="bi bi-info-circle-fill me-2"></i>
                            <small>Se creará un usuario del sistema con acceso SSH y fecha de expiración automática.</small>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="bi bi-x-circle"></i> Cancelar
                        </button>
                        <button type="submit" class="btn btn-success">
                            <i class="bi bi-check-circle-fill"></i> Crear Usuario
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF_DASH

    ui_info "Configurando servicio systemd..."
    cat > /etc/systemd/system/hex-webpanel.service <<EOF
[Unit]
Description=Hex Web Panel
After=network.target
[Service]
User=root
WorkingDirectory=/opt/hex-webpanel
Environment="PATH=/opt/hex-webpanel/venv/bin"
ExecStart=/opt/hex-webpanel/venv/bin/python app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable hex-webpanel.service >/dev/null 2>&1
    
    ui_info "Abriendo puerto 9000 en firewall..."
    iptables -I INPUT -p tcp --dport 9000 -j ACCEPT 2>/dev/null
    command -v ufw >/dev/null 2>&1 && ufw allow 9000/tcp >/dev/null 2>&1
    
    ui_info "Iniciando Panel Web..."
    systemctl start hex-webpanel.service
    sleep 2
    
    if systemctl is-active --quiet hex-webpanel.service; then
        ui_ok "Panel Web instalado y activo"
        ui_fila "  ${BOLD}URL:${NC} ${CYAN}http://$(hostname -I | awk '{print $1}'):9000${NC}"
        ui_fila "  ${BOLD}Pass:${NC} ${YELLOW}HexAdmin2026${NC} (Cámbiala en el menú)"
        ui_fila "  ${BOLD}Diseño:${NC} ${GREEN}Moderno con Modal de usuarios${NC}"
    else
        ui_error "El panel no pudo iniciar. Revisa los logs."
    fi
    ui_fila ""; pause_return
}

gestionar_webpanel() {
    while true; do
        clear; ui_top; ui_titulo "GESTIÓN PANEL WEB"; ui_sep
        
        if [ ! -f "/opt/hex-webpanel/app.py" ]; then
            ui_fila "  Estado: ${RED}● NO INSTALADO${NC}"
            ui_fila "  ${GRIS}El panel web aún no se ha configurado en este servidor${NC}"
            ui_sep; ui_fila ""
            
            ui_opcion "1" "Instalar Panel Web (Automático)"
            ui_opcion "0" "Atrás"
            
            ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
            
            case "$opt" in
                1) instalar_panel_web_automatico ;;
                0) break ;;
                *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
            esac
        else
            webpanel_state=$(systemctl is-active hex-webpanel.service 2>/dev/null || echo "inactivo")
            [ "$webpanel_state" = "active" ] && webpanel_status="${GREEN}● ACTIVO${NC}" || webpanel_status="${RED}● INACTIVO${NC}"
            
            ui_fila "  Estado: $webpanel_status  │  Puerto: ${YELLOW}9000${NC}"
            ui_fila "  URL: ${CYAN}http://$(hostname -I | awk '{print $1}'):9000${NC}"
            ui_sep; ui_fila ""
            
            ui_opcion "1" "Iniciar Panel Web"
            ui_opcion "2" "Detener Panel Web"
            ui_opcion "3" "Reiniciar Panel Web"
            ui_opcion "4" "Ver estado detallado"
            ui_opcion "5" "Cambiar contraseña de admin"
            ui_opcion "6" "Ver logs del panel"
            ui_opcion "7" "Desinstalar Panel Web"
            ui_opcion "0" "Atrás"
            
            ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
            
            case "$opt" in
                1) systemctl start hex-webpanel.service; sleep 1; systemctl is-active --quiet hex-webpanel.service && echo -e "  ${GREEN}✓ Panel Web iniciado${NC}" || echo -e "  ${RED}✗ Error al iniciar${NC}"; pause_return ;;
                2) systemctl stop hex-webpanel.service; echo -e "  ${GREEN}✓ Panel Web detenido${NC}"; pause_return ;;
                3) systemctl restart hex-webpanel.service; echo -e "  ${GREEN}✓ Panel Web reiniciado${NC}"; pause_return ;;
                4) echo ""; systemctl status hex-webpanel.service --no-pager; pause_return ;;
                5)
                    clear; ui_top; ui_titulo "CAMBIAR CONTRASEÑA"; ui_sep; ui_fila ""
                    echo -ne "  ${WHITE}Nueva contraseña:${NC} "; read -rs new_pass; echo ""
                    if [ -z "$new_pass" ]; then echo -e "  ${RED}✗ La contraseña no puede estar vacía${NC}"; pause_return; continue; fi
                    sed -i "s/ADMIN_PASSWORD = .*/ADMIN_PASSWORD = \"$new_pass\"/" /opt/hex-webpanel/app.py
                    systemctl restart hex-webpanel.service
                    echo -e "  ${GREEN}✓ Contraseña actualizada${NC}"; pause_return
                    ;;
                6) echo ""; journalctl -u hex-webpanel.service -n 50 --no-pager; pause_return ;;
                7)
                    echo -e "  ${CYAN}Desinstalando Panel Web...${NC}"
                    systemctl stop hex-webpanel.service 2>/dev/null; systemctl disable hex-webpanel.service 2>/dev/null
                    rm -f /etc/systemd/system/hex-webpanel.service; rm -rf /opt/hex-webpanel
                    systemctl daemon-reload
                    echo -e "  ${GREEN}✓ Panel Web desinstalado${NC}"; pause_return
                    ;;
                0) break ;;
                *) echo -e "  ${RED}✗ Opción inválida${NC}"; pause_return ;;
            esac
        fi
    done
    menu_principal
}

# ═══════════════════════════════════════════════════════════════
#  GESTIÓN DE USUARIOS Y LIMPIEZA
# ═══════════════════════════════════════════════════════════════

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
    echo -e "  ${BOLD}IP:${NC} $(hostname -I | awk '{print $1}')"
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
    [ ! -s "$USER_DB" ] && { echo ""; echo -e "  ${YELLOW}⚠ No hay usuarios registrados${NC}"; ui_sep; ui_fila ""; ui_fila "  ${GRIS}Usa la opción 5 para agregar usuarios${NC}"; ui_fila ""; pause_return; menu_principal; return; }
    
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
    ui_opcion "4" "BHTTP (todas)"; ui_opcion "5" "HCR (todas)"; ui_opcion "6" "Limpieza automática"; ui_opcion "7" "Panel Web"; ui_opcion "0" "Atrás"
    ui_bot; echo ""; echo -ne "  ${CYAN}►${NC} Selecciona opción: "; read -r opt
    
    case "$opt" in
        1) echo ""; journalctl -u "bhttp@*.service" -n 50 --no-pager; pause_return ;;
        2) echo ""; journalctl -u "hcr@*.service" -n 50 --no-pager; pause_return ;;
        3) echo ""; [ -f "$UDPGW_PORTS_CONF" ] && while read -r port; do [ -z "$port" ] && continue; echo -e "${YELLOW}═══ Puerto $port ═══${NC}"; journalctl -u "udpgw@${port}.service" -n 20 --no-pager; echo ""; done < "$UDPGW_PORTS_CONF" || echo -e "  ${YELLOW}Sin puertos${NC}"; pause_return ;;
        4) journalctl -u "bhttp@*.service" --no-pager | less ;;
        5) journalctl -u "hcr@*.service" --no-pager | less ;;
        6) [ -f "$CLEANUP_LOG" ] && tail -100 "$CLEANUP_LOG" | less || { echo -e "  ${YELLOW}Sin log${NC}"; pause_return; } ;;
        7) echo ""; journalctl -u hex-webpanel.service -n 50 --no-pager; pause_return ;;
        0) ;; *) echo -e "  ${RED}✗ Inválida${NC}"; pause_return ;;
    esac
    menu_principal
}

desinstalar() {
    clear; ui_top; ui_titulo "DESINSTALAR TODO"; ui_sep; ui_fila ""; ui_fila "  ${YELLOW}⚠${NC}  Estás a punto de desinstalar TODO el sistema HEX"; ui_fila ""; ui_sep
    echo ""; echo -ne "  ${RED}✗ Escriba${NC} ${YELLOW}${BOLD}CONFIRMAR${NC} ${RED}para continuar:${NC} "; read -r confirm
    
    if [ "$confirm" = "CONFIRMAR" ]; then
        echo -e "  ${CYAN}Deteniendo servicios...${NC}"
        for svc in bhttp hcr udpgw; do
            conf="/etc/hex/${svc}_ports.conf"
            [ -f "$conf" ] && while read -r port; do [ -z "$port" ] && continue; systemctl stop "${svc}@${port}.service" 2>/dev/null || true; done < "$conf"
        done
        
        echo -e "  ${CYAN}Eliminando Panel Web...${NC}"
        systemctl stop hex-webpanel.service 2>/dev/null || true
        systemctl disable hex-webpanel.service 2>/dev/null || true
        rm -f /etc/systemd/system/hex-webpanel.service
        rm -rf /opt/hex-webpanel
        
        echo -e "  ${CYAN}Eliminando archivos del sistema...${NC}"
        rm -f /etc/systemd/system/bhttp@.service /etc/systemd/system/hcr@.service /etc/systemd/system/udpgw@.service
        rm -rf /opt/bhttp /opt/hcr /opt/udpgw /etc/bhttp /etc/hcr /etc/hex
        rm -f /usr/local/bin/hex_menu /usr/bin/hex_menu /usr/local/bin/hex_cleanup.sh /var/log/hex-cleanup.log
        rm -f /etc/hex/bhttp_ports.conf /etc/hex/hcr_ports.conf /etc/hex/udpgw_ports.conf
        
        echo -e "  ${CYAN}Eliminando usuarios del grupo hexusers...${NC}"
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