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

# Rutas absolutas de comandos del sistema
SYSTEMCTL = '/usr/bin/systemctl'
USERADD = '/usr/sbin/useradd'
USERDEL = '/usr/sbin/userdel'
USERMOD = '/usr/sbin/usermod'
CHPASSWD = '/usr/sbin/chpasswd'
CHAGE = '/usr/bin/chage'
GROUPADD = '/usr/sbin/groupadd'
ID = '/usr/bin/id'
GETENT = '/usr/bin/getent'

# Archivo de configuración del puerto
WEBPANEL_PORT_FILE = "/etc/hex/webpanel_port.conf"

def get_webpanel_port():
    try:
        if os.path.exists(WEBPANEL_PORT_FILE):
            return int(open(WEBPANEL_PORT_FILE).read().strip())
    except:
        pass
    return 9000

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
        
        bhttp_active = sum(1 for p in bhttp_ports if get_service_status("bhttp", p))
        hcr_active = sum(1 for p in hcr_ports if get_service_status("hcr", p))
        udpgw_active = sum(1 for p in udpgw_ports if get_service_status("udpgw", p))
        
        stats = {
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
            "webpanel_port": get_webpanel_port()
        }
        return render_template('dashboard.html', stats=stats, users=get_users())
    except Exception as e:
        logging.error(f"Error en dashboard: {e}")
        flash(f"Error al cargar dashboard: {str(e)}")
        return render_template('dashboard.html', stats={
            "bhttp_ports":[], "hcr_ports":[], "udpgw_ports":[],
            "bhttp_active":0, "hcr_active":0, "udpgw_active":0,
            "bhttp_online":False, "hcr_online":False, "udpgw_online":False,
            "users":0, "webpanel_port":9000
        }, users=[])

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
    web_port = get_webpanel_port()
    app.run(host='0.0.0.0', port=web_port, debug=False)