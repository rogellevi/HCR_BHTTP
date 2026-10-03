# 🚀 MANAGER - Panel de Gestión Completo

<div align="center">

![Version](https://img.shields.io/badge/version-3.1.2-00c853?style=for-the-badge&logo=github)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

**Sistema todo-en-uno para gestión de servicios BHTTP, HCR, UDPGW y Panel Web**

[Instalación](#-instalación-rápida) • [Características](#-características) • [Uso](#-uso) • [Documentación](#-documentación)

</div>

---

## 📖 Descripción

**MANAGER** es un sistema completo de administración de servidores que permite gestionar múltiples servicios de túnel (BHTTP, HCR, UDPGW) con una interfaz de terminal elegante y un **Panel Web moderno** con diseño glassmorphism. Incluye gestión automática de usuarios con expiración, limpieza programada y sistema de actualizaciones OTA desde GitHub.

## ✨ Características

### 🖥️ Menú de Terminal
- ✅ Gestión de **múltiples puertos** para BHTTP, HCR y UDPGW
- ✅ Creación de usuarios del sistema con **expiración automática**
- ✅ **Limpieza automática** diaria de usuarios expirados (cron)
- ✅ Control individual y masivo de servicios
- ✅ Visualización de logs en tiempo real
- ✅ Desinstalación completa con un clic

### 🌐 Panel Web
- 🎨 Diseño moderno con **glassmorphism** y gradientes animados
- 📱 **100% Responsive** (funciona en móviles y desktop)
- 🔐 Login seguro con autenticación
- 📊 Dashboard con indicadores **ONLINE/OFFLINE** animados
- 👥 Modal elegante para agregar usuarios
- 🎛️ Botones de Iniciar/Detener/Reiniciar por servicio
- ⚙️ Cambio de puerto del panel desde la interfaz

### 🔄 Sistema de Actualizaciones
- 🔍 Detección automática de nuevas versiones
- 📦 Actualización granular (menú, templates, backend)
- 💾 Backups automáticos antes de actualizar
- ✅ Validación de sintaxis antes de aplicar cambios
- 📝 Changelog integrado

## 🎯 Requisitos

- **Sistema Operativo:** Ubuntu 22.04 o superior
- **Permisos:** Root (sudo)
- **Arquitectura:** x86_64 (amd64) o ARM64
- **Conexión:** Internet para la instalación inicial

## 🚀 Instalación Rápida

### Método 1: Instalación completa (todo en uno)

```bash
curl -sSL https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main/install.sh | bash
```

### Método 2: Solo Panel Web (si ya tienes el sistema instalado)

```bash
curl -sSL https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main/install_webpanel.sh | bash
```

### Método 3: Instalación manual

```bash
git clone https://github.com/rogellevi/HCR_BHTTP.git
cd HCR_BHTTP
sudo bash install.sh
```

### Otros

```
wget -qO- https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main/install.sh | bash
```

```
curl -sSL https://raw.githubusercontent.com/rogellevi/HCR_BHTTP/main/install.sh | bash
```