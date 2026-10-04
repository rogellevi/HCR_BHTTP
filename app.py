import os, subprocess, datetime, logging, time, json, threading
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user

logging.basicConfig(filename='/var/log/hex-webpanel.log', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)
app.secret_key = 'hex_secret_key_cambiar_123'
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
ADMIN_PASSWORD = "HexAdmin2026"
PASSWORD_FILE = "/etc/hex/webpanel_admin_pass.conf"

# Rutas absolutas
SYSTEMCTL = '/usr/bin/systemctl'
USERADD = '/usr/sbin/useradd'
USERDEL = '/usr/sbin/userdel'
USERMOD = '/usr/sbin/usermod'
CHPASSWD = '/usr/sbin/chpasswd'
CHAGE = '/usr/bin/chage'
GROUPADD = '/usr/sbin/groupadd'
ID = '/usr/bin/id'
GETENT = '/usr/bin/getent'
CURL = '/usr/bin/curl'
BASH = '/bin/bash'

# Archivos de configuración
WEBPANEL_PORT_FILE = "/etc/hex/webpanel_port.conf"
VERSION_FILE = "/etc/hex/version"
UPDATE_CACHE_FILE = "/tmp/hex_update_cache.json"
GITHUB_RAW = "https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main"
CACHE_DURATION = 300

def get_webpanel_port():
    try:
        if os.path.exists(WEBPANEL_PORT_FILE):
            return int(open(WEBPANEL_PORT_FILE).read().strip())
    except:
        pass
    return 9000

def load_admin_password():
    """Carga la contraseña desde archivo o usa la por defecto"""
    global ADMIN_PASSWORD
    try:
        if os.path.exists(PASSWORD_FILE):
            ADMIN_PASSWORD = open(PASSWORD_FILE).read().strip()
    except:
        pass
    return ADMIN_PASSWORD

def save_admin_password(new_password):
    """Guarda la nueva contraseña en archivo"""
    global ADMIN_PASSWORD
    try:
        os.makedirs(os.path.dirname(PASSWORD_FILE), exist_ok=True)
        with open(PASSWORD_FILE, 'w') as f:
            f.write(new_password)
        os.chmod(PASSWORD_FILE, 0o600)
        ADMIN_PASSWORD = new_password
        return True
    except Exception as e:
        logging.error(f"Error guardando contraseña: {e}")
        return False

# Cargar contraseña al iniciar
load_admin_password()

class User(UserMixin):
    def __init__(self, id): self.id = id

@login_manager.user_loader
def load_user(user_id): return User(user_id)

def get_service_status(svc, port):
    try:
        result = subprocess.run([SYSTEMCTL, 'is-active', f"{svc}@{port}.service"], 
                              capture_output=True, text=True)
        return result.returncode == 0 and "active" in result.stdout
    except:
        return False

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

# ═══════════════════════════════════════════════════════════════
#  SISTEMA DE ACTUALIZACIONES
# ═══════════════════════════════════════════════════════════════

def get_local_version():
    try:
        if os.path.exists(VERSION_FILE):
            return open(VERSION_FILE).read().strip()
    except:
        pass
    return "3.1.2"

def check_updates():
    try:
        if os.path.exists(UPDATE_CACHE_FILE):
            cache_age = time.time() - os.path.getmtime(UPDATE_CACHE_FILE)
            if cache_age < CACHE_DURATION:
                with open(UPDATE_CACHE_FILE, 'r') as f:
                    return json.load(f)
        
        local_version = get_local_version()
        import urllib.request
        req = urllib.request.Request(
            f"{GITHUB_RAW}/version.json",
            headers={'User-Agent': 'HexWebPanel/1.0'}
        )
        with urllib.request.urlopen(req, timeout=3) as response:
            remote_data = json.loads(response.read().decode())
        
        remote_version = remote_data.get('version', local_version)
        changelog = remote_data.get('changelog', 'Nuevas mejoras disponibles')
        has_update = remote_version != local_version
        
        result = {
            "has_update": has_update,
            "local_version": local_version,
            "remote_version": remote_version,
            "changelog": changelog,
            "checked_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        with open(UPDATE_CACHE_FILE, 'w') as f:
            json.dump(result, f)
        
        return result
    except Exception as e:
        logging.error(f"Error verificando actualizaciones: {e}")
        return {
            "has_update": False,
            "local_version": get_local_version(),
            "remote_version": get_local_version(),
            "changelog": "",
            "checked_at": "",
            "error": True
        }

def invalidate_update_cache():
    try:
        if os.path.exists(UPDATE_CACHE_FILE):
            os.remove(UPDATE_CACHE_FILE)
    except:
        pass

def schedule_restart():
    def restart_later():
        time.sleep(2)
        try:
            subprocess.run([SYSTEMCTL, 'restart', 'hex-webpanel.service'], 
                          capture_output=True, timeout=10)
        except:
            pass
    thread = threading.Thread(target=restart_later, daemon=True)
    thread.start()

def perform_update():
    results = {
        "menu": {"success": False, "message": ""},
        "templates": {"success": False, "message": ""},
        "backend": {"success": False, "message": ""},
        "version": {"success": False, "message": ""}
    }
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    try:
        menu_backup = f"/usr/local/bin/hex_menu.backup.{timestamp}"
        if os.path.exists("/usr/local/bin/hex_menu"):
            subprocess.run(['cp', '/usr/local/bin/hex_menu', menu_backup], capture_output=True)
        res = subprocess.run([CURL, '-fsSL', f"{GITHUB_RAW}/hex_menu.sh", '-o', '/tmp/hex_menu_new.sh'],
                           capture_output=True, text=True, timeout=30)
        if res.returncode == 0 and os.path.exists('/tmp/hex_menu_new.sh'):
            syntax_check = subprocess.run([BASH, '-n', '/tmp/hex_menu_new.sh'], capture_output=True)
            if syntax_check.returncode == 0:
                subprocess.run(['mv', '/tmp/hex_menu_new.sh', '/usr/local/bin/hex_menu'], capture_output=True)
                os.chmod('/usr/local/bin/hex_menu', 0o755)
                results["menu"] = {"success": True, "message": "Menú actualizado"}
            else:
                results["menu"] = {"success": False, "message": "Error de sintaxis"}
        else:
            results["menu"] = {"success": False, "message": "Error de descarga"}
    except Exception as e:
        results["menu"] = {"success": False, "message": str(e)}
    
    try:
        templates_dir = "/opt/hex-webpanel/templates"
        if os.path.exists(templates_dir):
            backup_dir = f"{templates_dir}.backup.{timestamp}"
            subprocess.run(['cp', '-r', templates_dir, backup_dir], capture_output=True)
            login_ok = subprocess.run([CURL, '-fsSL', f"{GITHUB_RAW}/templates/login.html", 
                                      '-o', f"{templates_dir}/login.html"], capture_output=True, timeout=30).returncode == 0
            dash_ok = subprocess.run([CURL, '-fsSL', f"{GITHUB_RAW}/templates/dashboard.html", 
                                     '-o', f"{templates_dir}/dashboard.html"], capture_output=True, timeout=30).returncode == 0
            if login_ok and dash_ok:
                results["templates"] = {"success": True, "message": "Templates actualizados"}
            else:
                results["templates"] = {"success": False, "message": "Error en algunos templates"}
        else:
            results["templates"] = {"success": True, "message": "Panel no instalado, omitido"}
    except Exception as e:
        results["templates"] = {"success": False, "message": str(e)}
    
    try:
        if os.path.exists("/opt/hex-webpanel/app.py"):
            app_backup = f"/opt/hex-webpanel/app.py.backup.{timestamp}"
            subprocess.run(['cp', '/opt/hex-webpanel/app.py', app_backup], capture_output=True)
            res = subprocess.run([CURL, '-fsSL', f"{GITHUB_RAW}/app.py", '-o', '/tmp/app_new.py'],
                               capture_output=True, text=True, timeout=30)
            if res.returncode == 0 and os.path.exists('/tmp/app_new.py'):
                syntax_check = subprocess.run(['python3', '-m', 'py_compile', '/tmp/app_new.py'], capture_output=True)
                if syntax_check.returncode == 0:
                    subprocess.run(['mv', '/tmp/app_new.py', '/opt/hex-webpanel/app.py'], capture_output=True)
                    results["backend"] = {"success": True, "message": "Backend actualizado"}
                else:
                    results["backend"] = {"success": False, "message": "Error de sintaxis"}
            else:
                results["backend"] = {"success": False, "message": "Error de descarga"}
        else:
            results["backend"] = {"success": True, "message": "Panel no instalado, omitido"}
    except Exception as e:
        results["backend"] = {"success": False, "message": str(e)}
    
    try:
        res = subprocess.run([CURL, '-fsSL', f"{GITHUB_RAW}/version.json", '-o', '/tmp/version_new.json'],
                           capture_output=True, text=True, timeout=30)
        if res.returncode == 0 and os.path.exists('/tmp/version_new.json'):
            with open('/tmp/version_new.json', 'r') as f:
                version_data = json.load(f)
            new_version = version_data.get('version', '')
            if new_version:
                with open(VERSION_FILE, 'w') as f:
                    f.write(new_version)
                results["version"] = {"success": True, "message": f"Versión actualizada a {new_version}"}
            os.remove('/tmp/version_new.json')
        else:
            results["version"] = {"success": False, "message": "Error al obtener versión"}
    except Exception as e:
        results["version"] = {"success": False, "message": str(e)}
    
    invalidate_update_cache()
    logging.info(f"Actualización completada: {results}")
    return results

def get_stats_data():
    """Obtiene todas las estadísticas (usado por dashboard y API)"""
    try:
        bhttp_ports = open("/etc/hex/bhttp_ports.conf").read().splitlines() if os.path.exists("/etc/hex/bhttp_ports.conf") else []
        hcr_ports = open("/etc/hex/hcr_ports.conf").read().splitlines() if os.path.exists("/etc/hex/hcr_ports.conf") else []
        udpgw_ports = open("/etc/hex/udpgw_ports.conf").read().splitlines() if os.path.exists("/etc/hex/udpgw_ports.conf") else []
        
        bhttp_active = sum(1 for p in bhttp_ports if get_service_status("bhttp", p))
        hcr_active = sum(1 for p in hcr_ports if get_service_status("hcr", p))
        udpgw_active = sum(1 for p in udpgw_ports if get_service_status("udpgw", p))
        
        return {
            "bhttp_ports": [p for p in bhttp_ports if p.strip()],
            "hcr_ports": [p for p in hcr_ports if p.strip()],
            "udpgw_ports": [p for p in udpgw_ports if p.strip()],
            "bhttp_active": bhttp_active,
            "hcr_active": hcr_active,
            "udpgw_active": udpgw_active,
            "bhttp_online": bhttp_active > 0,
            "hcr_online": hcr_active > 0,
            "udpgw_online": udpgw_active > 0,
            "users": len(get_users()),
            "webpanel_port": get_webpanel_port(),
            "update_info": check_updates()
        }
    except Exception as e:
        logging.error(f"Error obteniendo stats: {e}")
        return None

# ═══════════════════════════════════════════════════════════════
#  RUTAS
# ═══════════════════════════════════════════════════════════════

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
    stats = get_stats_data()
    if stats is None:
        flash("Error al cargar el dashboard")
        stats = {
            "bhttp_ports":[], "hcr_ports":[], "udpgw_ports":[],
            "bhttp_active":0, "hcr_active":0, "udpgw_active":0,
            "bhttp_online":False, "hcr_online":False, "udpgw_online":False,
            "users":0, "webpanel_port":9000,
            "update_info": {"has_update": False, "local_version": "3.1.2", 
                          "remote_version": "3.1.2", "changelog": "", "checked_at": "", "error": True}
        }
    return render_template('dashboard.html', stats=stats, users=get_users())

@app.route('/api/stats')
@login_required
def api_stats():
    """API para auto-refresh: retorna JSON con estadísticas"""
    stats = get_stats_data()
    if stats is None:
        return jsonify({"error": "No se pudieron obtener las estadísticas"}), 500
    return jsonify(stats)

@app.route('/change_password', methods=['POST'])
@login_required
def change_password():
    """Cambia la contraseña del administrador"""
    try:
        current_pass = request.form.get('current_password', '')
        new_pass = request.form.get('new_password', '')
        confirm_pass = request.form.get('confirm_password', '')
        
        # Validaciones
        if current_pass != ADMIN_PASSWORD:
            return jsonify({"success": False, "message": "La contraseña actual es incorrecta"})
        
        if not new_pass or len(new_pass) < 4:
            return jsonify({"success": False, "message": "La nueva contraseña debe tener al menos 4 caracteres"})
        
        if new_pass != confirm_pass:
            return jsonify({"success": False, "message": "Las contraseñas nuevas no coinciden"})
        
        if new_pass == current_pass:
            return jsonify({"success": False, "message": "La nueva contraseña debe ser diferente a la actual"})
        
        # Guardar nueva contraseña
        if save_admin_password(new_pass):
            logging.info("Contraseña de administrador cambiada exitosamente")
            return jsonify({"success": True, "message": "✓ Contraseña cambiada exitosamente"})
        else:
            return jsonify({"success": False, "message": "Error al guardar la contraseña"})
            
    except Exception as e:
        logging.error(f"Error cambiando contraseña: {e}", exc_info=True)
        return jsonify({"success": False, "message": f"Error: {str(e)}"})

@app.route('/update_now', methods=['POST'])
@login_required
def update_now():
    try:
        logging.info("Iniciando actualización desde el panel web")
        results = perform_update()
        
        if results["backend"]["success"] or results["templates"]["success"]:
            schedule_restart()
            restart_msg = "El panel se reiniciará automáticamente en unos segundos."
        else:
            restart_msg = ""
        
        success_count = sum(1 for k, v in results.items() if v["success"])
        total_count = len(results)
        
        return jsonify({
            "success": True,
            "message": f"Actualización completada: {success_count}/{total_count} componentes",
            "details": results,
            "restart": restart_msg,
            "will_reload": results["backend"]["success"] or results["templates"]["success"]
        })
    except Exception as e:
        logging.error(f"Error en actualización: {e}", exc_info=True)
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500

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
            flash(f"Error al crear usuario: {res.stderr}")
            return redirect(url_for('dashboard'))
        
        res_pwd = subprocess.run([CHPASSWD], input=f"{user}:{pwd}", text=True, capture_output=True)
        if res_pwd.returncode != 0:
            flash(f"Error al establecer contraseña: {res_pwd.stderr}")
            subprocess.run([USERDEL, '-r', user], capture_output=True)
            return redirect(url_for('dashboard'))
        
        subprocess.run([CHAGE, '-E', exp_date, user], capture_output=True)
        subprocess.run([USERMOD, '-e', exp_date, user], capture_output=True)
        
        with open("/etc/hex/users.txt", "a") as f: 
            f.write(f"{user}:{pwd}:{exp_date}\n")
        
        flash(f"✓ Usuario '{user}' creado exitosamente (Expira: {exp_date})")
        return redirect(url_for('dashboard'))
    except ValueError:
        flash("Error: Los días deben ser un número válido")
        return redirect(url_for('dashboard'))
    except Exception as e:
        logging.error(f"Error creando usuario: {str(e)}", exc_info=True)
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
        flash(f"✓ Usuario '{username}' eliminado correctamente")
    except Exception as e:
        logging.error(f"Error eliminando usuario: {e}")
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
            result = subprocess.run([SYSTEMCTL, action, service_name], capture_output=True, text=True)
            if result.returncode == 0:
                success_count += 1
            else:
                error_count += 1
        
        if error_count == 0:
            flash(f"✓ {svc.upper()}: {action.capitalize()} exitoso en {success_count} puerto(s)")
        else:
            flash(f"⚠ {svc.upper()}: {success_count} exitoso(s), {error_count} error(es)")
    except Exception as e:
        logging.error(f"Error controlando servicio: {e}")
        flash(f"Error: {str(e)}")
    return redirect(url_for('dashboard'))

if __name__ == '__main__':
    web_port = get_webpanel_port()
    app.run(host='0.0.0.0', port=web_port, debug=False)