# Webserver Container Manager - Anleitung

Automatisiertes Management eines Webserver-Containers mit Auto-Start-Funktionalität.

## 🚀 Schnellstart

```bash
# 1. Konfiguration erstellen
./webserver-manager.sh config

# 2. Optional: Konfiguration anpassen
nano ~/.config/container-webserver/config.env

# 3. Webserver starten
./webserver-manager.sh start

# 4. Auto-Start beim System-Boot aktivieren
./webserver-manager.sh autostart
```

## 📋 Verfügbare Befehle

### Container-Verwaltung

```bash
# Container starten
./webserver-manager.sh start

# Container stoppen
./webserver-manager.sh stop

# Container neustarten
./webserver-manager.sh restart

# Status anzeigen
./webserver-manager.sh status

# Informationen anzeigen
./webserver-manager.sh info
```

### Logs & Monitoring

```bash
# Letzte 50 Log-Zeilen anzeigen
./webserver-manager.sh logs

# Live-Logs verfolgen
./webserver-manager.sh logs follow
```

### System-Updates

```bash
# Auf Container-System-Updates prüfen
./webserver-manager.sh update
```

### Auto-Start

```bash
# Auto-Start beim System-Boot aktivieren
./webserver-manager.sh autostart

# Auto-Start deaktivieren
./webserver-manager.sh disable
```

## ⚙️ Konfiguration

Die Konfigurationsdatei befindet sich unter:
```
~/.config/container-webserver/config.env
```

### Verfügbare Optionen

```bash
# Container-Name
CONTAINER_NAME="webserver"

# Docker/OCI Image
# Beispiele: nginx:alpine, httpd:alpine, python:3-alpine
IMAGE_NAME="nginx:alpine"

# Port-Mapping (Host:Container)
# Format: [HOST_IP:]HOST_PORT:CONTAINER_PORT
# Mit lokaler IP für lokalen Zugriff: 127.0.0.1:8080:80
# Ohne IP (nicht empfohlen): 8080:80
PORT_MAPPING="127.0.0.1:8080:80"

# Volume-Mount (optional)
# Format: /host/path:/container/path
VOLUME_MOUNT="/Users/username/website:/usr/share/nginx/html"

# Ressourcen
MEMORY="2g"
CPUS="2"

# Auto-Update beim Start
AUTO_UPDATE="false"
```

## 🌐 Webserver-Beispiele

### Nginx (Standard)

```bash
IMAGE_NAME="nginx:alpine"
PORT_MAPPING="127.0.0.1:8080:80"
VOLUME_MOUNT="/Users/username/html:/usr/share/nginx/html"
```

Zugriff: http://localhost:8080

### Apache

```bash
IMAGE_NAME="httpd:alpine"
PORT_MAPPING="127.0.0.1:8080:80"
VOLUME_MOUNT="/Users/username/html:/usr/local/apache2/htdocs"
```

### Python HTTP Server

```bash
IMAGE_NAME="python:3-alpine"
PORT_MAPPING="127.0.0.1:8000:8000"
VOLUME_MOUNT="/Users/username/app:/app"
```

Container-Befehl anpassen für Python:
```bash
container run -d --name webserver \
  -p 127.0.0.1:8000:8000 \
  -v /Users/username/app:/app \
  python:3-alpine \
  python -m http.server 8000 --directory /app
```

## 🔄 Auto-Start beim System-Boot

### Einrichten

```bash
./webserver-manager.sh autostart
```

Dies erstellt einen LaunchAgent unter:
```
~/Library/LaunchAgents/com.container.webserver.plist
```

Der Container wird automatisch gestartet wenn:
- Der Benutzer sich anmeldet
- Das System neu gestartet wird

### Deaktivieren

```bash
./webserver-manager.sh disable
```

### Manuelles Verwalten des LaunchAgents

```bash
# Status prüfen
launchctl list | grep container.webserver

# Manuell laden
launchctl load ~/Library/LaunchAgents/com.container.webserver.plist

# Manuell entladen
launchctl unload ~/Library/LaunchAgents/com.container.webserver.plist
```

## 📊 Monitoring & Logs

### Log-Dateien

Logs werden gespeichert unter:
```
~/.config/container-webserver/webserver.log
```

### Logs anzeigen

```bash
# Manager-Logs
tail -f ~/.config/container-webserver/webserver.log

# Container-Logs
./webserver-manager.sh logs follow
```

## 🔧 Erweiterte Verwendung

### Mehrere Webserver verwalten

Erstelle separate Scripts mit unterschiedlichen Konfigurationen:

```bash
# Kopiere das Script
cp webserver-manager.sh api-server-manager.sh

# Setze Environment-Variablen
export CONTAINER_NAME="api-server"
export IMAGE_NAME="node:alpine"
export PORT_MAPPING="127.0.0.1:3000:3000"

./api-server-manager.sh start
```

### Custom Images verwenden

1. Erstelle ein Dockerfile
2. Baue das Image:
   ```bash
   container build -t my-webserver:latest .
   ```
3. Konfiguriere den Manager:
   ```bash
   IMAGE_NAME="my-webserver:latest"
   ```

### Mit Docker Compose Migration

Falls du von Docker Compose migrierst:

```yaml
# docker-compose.yml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    mem_limit: 2g
    cpus: 2
```

Entsprechende Konfiguration:
```bash
IMAGE_NAME="nginx:alpine"
PORT_MAPPING="127.0.0.1:8080:80"
VOLUME_MOUNT="$(pwd)/html:/usr/share/nginx/html"
MEMORY="2g"
CPUS="2"
```

## 🔒 Sicherheit

### Best Practices

1. **Nicht-Root-User verwenden**
   - Alpine-basierte Images laufen oft als non-root
   - Prüfe Image-Dokumentation

2. **Port-Bindung**
   - Binde nur auf localhost: `127.0.0.1:8080:80`
   - Verhindert externen Zugriff

3. **Volume-Berechtigungen**
   - Prüfe Dateiberechtigungen in gemounteten Volumes
   - Verwende read-only Mounts wo möglich:
     ```bash
     VOLUME_MOUNT="/path/to/data:/data:ro"
     ```

4. **Ressourcen-Limits**
   - Setze immer Memory und CPU Limits
   - Verhindert Ressourcen-Exhaustion

## 🐛 Troubleshooting

### Container startet nicht

```bash
# Prüfe System-Status
container system status

# Prüfe Container-Logs
./webserver-manager.sh logs

# Prüfe Image
container image list | grep nginx
```

### Port bereits belegt

```bash
# Prüfe welcher Prozess den Port verwendet
lsof -i :8080

# Ändere Port in Config
PORT_MAPPING="8081:80"
```

### Auto-Start funktioniert nicht

```bash
# Prüfe LaunchAgent-Status
launchctl list | grep container.webserver

# Prüfe Logs
cat ~/.config/container-webserver/webserver.log

# Lade LaunchAgent neu
launchctl unload ~/Library/LaunchAgents/com.container.webserver.plist
launchctl load ~/Library/LaunchAgents/com.container.webserver.plist
```

### Container läuft aber ist nicht erreichbar

```bash
# Prüfe Container-IP
./webserver-manager.sh info

# Teste direkt mit Container-IP
curl http://192.168.64.X

# Prüfe Port-Forwarding
container list | grep webserver
```

## 📚 Weitere Ressourcen

- **Apple Container Docs**: https://github.com/apple/container
- **Nginx Docs**: https://nginx.org/en/docs/
- **OCI Image Spec**: https://github.com/opencontainers/image-spec

## 🔄 Update-Workflow

### Container-System aktualisieren

```bash
# Mit Auto-Update
AUTO_UPDATE="true" ./webserver-manager.sh start

# Manuell
./update-container.sh
```

### Container-Image aktualisieren

```bash
# Neues Image pullen
container image pull nginx:alpine

# Container neu erstellen
./webserver-manager.sh stop
container rm webserver
./webserver-manager.sh start
```

## 💡 Tipps

1. **Test vor Auto-Start**: Teste den Container manuell bevor du Auto-Start aktivierst
2. **Backup**: Sichere wichtige Daten vor Updates
3. **Monitoring**: Überprüfe regelmäßig die Logs
4. **Updates**: Halte Images und Container-System aktuell
5. **Dokumentation**: Dokumentiere deine spezifische Konfiguration

---

**Entwickelt mit [Claude Code](https://claude.com/claude-code)**
