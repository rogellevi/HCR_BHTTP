#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  HEX MANAGER - MENÚ DE GESTIÓN COMPLETO (v2.1 - Corregido)
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
#  GESTIÓN DEL PANEL WEB (INTELIGENTE)
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
import os, subprocess, datetime
from flask import Flask, render_template, request, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user

app = Flask(__name__)
app.secret_key = 'hex_secret_key_cambiar_123'
login_manager = LoginManager(); login_manager.init_app(app); login_manager.login_view = 'login'
ADMIN_PASSWORD = "HexAdmin2026"

class User(UserMixin):
    def __init__(self, id): self.id = id
@login_manager.user_loader
def load_user(user_id): return User(user_id)

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e: return False, e.stderr

def get_service_status(svc, port):
    try:
        result = subprocess.run(f"systemctl is-active {svc}@{port}.service", shell=True, capture_output=True, text=True)
        return result.returncode == 0 and "active" in result.stdout
    except: return False

def get_users():
    users = []
    if os.path.exists("/etc/hex/users.txt"):
        with open("/etc/hex/users.txt", "r") as f:
            for line in f:
                parts = line.strip().split(":")
                if len(parts) == 3: users.append({"user": parts[0], "exp": parts[2]})
    return users

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form['password'] == ADMIN_PASSWORD:
            login_user(User("admin")); return redirect(url_for('dashboard'))
        flash('Contraseña incorrecta')
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout(): logout_user(); return redirect(url_for('login'))

@app.route('/')
@login_required
def dashboard():
    bhttp_ports = open("/etc/hex/bhttp_ports.conf").read().splitlines() if os.path.exists("/etc/hex/bhttp_ports.conf") else []
    hcr_ports = open("/etc/hex/hcr_ports.conf").read().splitlines() if os.path.exists("/etc/hex/hcr_ports.conf") else []
    udpgw_ports = open("/etc/hex/udpgw_ports.conf").read().splitlines() if os.path.exists("/etc/hex/udpgw_ports.conf") else []
    stats = {
        "bhttp": sum(1 for p in bhttp_ports if get_service_status("bhttp", p)),
        "hcr": sum(1 for p in hcr_ports if get_service_status("hcr", p)),
        "udpgw": sum(1 for p in udpgw_ports if get_service_status("udpgw", p)),
        "users": len(get_users())
    }
    return render_template('dashboard.html', stats=stats, users=get_users())

@app.route('/add_user', methods=['POST'])
@login_required
def add_user():
    user, pwd, days = request.form['username'], request.form['password'], int(request.form['days'])
    exp_date = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime("%Y-%m-%d")
    success1, msg1 = run_cmd(f"useradd -m -s /bin/bash -G hexusers {user} 2>/dev/null")
    if not success1 and "already exists" not in msg1:
        flash(f"Error: {msg1}"); return redirect(url_for('dashboard'))
    run_cmd(f"echo '{user}:{pwd}' | chpasswd")
    run_cmd(f"chage -E {exp_date} {user}"); run_cmd(f"usermod -e {exp_date} {user}")
    with open("/etc/hex/users.txt", "a") as f: f.write(f"{user}:{pwd}:{exp_date}\n")
    flash(f"Usuario {user} creado (Expira: {exp_date})")
    return redirect(url_for('dashboard'))

@app.route('/delete_user/<username>')
@login_required
def delete_user(username):
    run_cmd(f"userdel -r {username} 2>/dev/null"); run_cmd(f"sed -i '/^{username}:/d' /etc/hex/users.txt")
    flash(f"Usuario {username} eliminado"); return redirect(url_for('dashboard'))

@app.route('/restart_service/<svc>')
@login_required
def restart_service(svc):
    run_cmd(f"systemctl restart '{svc}@*.service' 2>/dev/null")
    flash(f"Servicio {svc.upper()} reiniciado"); return redirect(url_for('dashboard'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=False)
EOF_APP

    ui_info "Creando interfaz web..."
    cat > /opt/hex-webpanel/templates/login.html <<'EOF_LOGIN'
<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Hex Panel</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
<style>body{background-color:#121212;color:#e0e0e0;display:flex;align-items:center;justify-content:center;height:100vh}.card{background-color:#1e1e1e;border:1px solid #333}.btn-primary{background-color:#00c853;border:none}</style></head>
<body><div class="card p-4" style="width:350px"><h3 class="text-center mb-4 text-success">🔐 Hex Panel</h3>
{% with messages = get_flashed_messages() %}{% if messages %}<div class="alert alert-danger">{{ messages[0] }}</div>{% endif %}{% endwith %}
<form method="POST"><div class="mb-3"><label>Contraseña de Administrador</label>
<input type="password" name="password" class="form-control bg-dark text-light" required></div>
<button type="submit" class="btn btn-primary w-100">Ingresar</button></form></div></body></html>
EOF_LOGIN

    cat > /opt/hex-webpanel/templates/dashboard.html <<'EOF_DASH'
<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Hex Dashboard</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
<style>body{background-color:#121212;color:#e0e0e0}.card{background-color:#1e1e1e;border:1px solid #333}.text-success{color:#00c853!important}.table{color:#e0e0e0}.table-dark{background-color:#1e1e1e}</style></head>
<body><nav class="navbar navbar-dark bg-dark border-bottom border-secondary"><div class="container-fluid">
<span class="navbar-brand mb-0 h1">🚀 Hex Web Panel</span><a href="/logout" class="btn btn-outline-danger btn-sm">Cerrar Sesión</a></div></nav>
<div class="container mt-4">{% with messages = get_flashed_messages() %}{% if messages %}<div class="alert alert-success">{{ messages[0] }}</div>{% endif %}{% endwith %}
<div class="row mb-4">
<div class="col-md-3"><div class="card p-3 text-center"><h5 class="text-success">BHTTP</h5><h2>{{ stats.bhttp }} <small class="text-muted">Puertos</small></h2><a href="/restart_service/bhttp" class="btn btn-sm btn-outline-success mt-2">Reiniciar</a></div></div>
<div class="col-md-3"><div class="card p-3 text-center"><h5 class="text-info">HCR</h5><h2>{{ stats.hcr }} <small class="text-muted">Puertos</small></h2><a href="/restart_service/hcr" class="btn btn-sm btn-outline-info mt-2">Reiniciar</a></div></div>
<div class="col-md-3"><div class="card p-3 text-center"><h5 class="text-warning">UDPGW</h5><h2>{{ stats.udpgw }} <small class="text-muted">Puertos</small></h2><a href="/restart_service/udpgw" class="btn btn-sm btn-outline-warning mt-2">Reiniciar</a></div></div>
<div class="col-md-3"><div class="card p-3 text-center"><h5 class="text-primary">Usuarios</h5><h2>{{ stats.users }}</h2></div></div></div>
<div class="row"><div class="col-md-4"><div class="card p-3"><h5 class="mb-3">➕ Agregar Usuario</h5>
<form action="/add_user" method="POST"><div class="mb-2"><input type="text" name="username" class="form-control bg-dark text-light" placeholder="Usuario" required></div>
<div class="mb-2"><input type="text" name="password" class="form-control bg-dark text-light" placeholder="Contraseña" required></div>
<div class="mb-2"><input type="number" name="days" class="form-control bg-dark text-light" placeholder="Días" required></div>
<button type="submit" class="btn btn-success w-100">Crear Usuario</button></form></div></div>
<div class="col-md-8"><div class="card p-3"><h5 class="mb-3">👥 Usuarios Activos</h5><div class="table-responsive">
<table class="table table-dark table-hover"><thead><tr><th>Usuario</th><th>Expiración</th><th>Acción</th></tr></thead><tbody>
{% for u in users %}<tr><td>{{ u.user }}</td><td>{{ u.exp }}</td><td><a href="/delete_user/{{ u.user }}" class="btn btn-sm btn-danger" onclick="return confirm('¿Eliminar?')">🗑️</a></td></tr>{% else %}
<tr><td colspan="3" class="text-center text-muted">No hay usuarios</td></tr>{% endfor %}</tbody></table></div></div></div></div></div></body></html>
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