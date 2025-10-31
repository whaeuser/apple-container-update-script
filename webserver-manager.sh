#!/bin/bash

# Webserver Container Manager
# Verwaltet einen Webserver-Container mit Auto-Start und Update-Funktionalität

set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguration (kann über config-Datei überschrieben werden)
CONTAINER_NAME="${CONTAINER_NAME:-webserver}"
IMAGE_NAME="${IMAGE_NAME:-nginx:alpine}"
PORT_MAPPING="${PORT_MAPPING:-8080:80}"
VOLUME_MOUNT="${VOLUME_MOUNT:-}"
MEMORY="${MEMORY:-2g}"
CPUS="${CPUS:-2}"
AUTO_UPDATE="${AUTO_UPDATE:-false}"
RESTART_POLICY="${RESTART_POLICY:-always}"

# Pfade
CONFIG_FILE="${HOME}/.config/container-webserver/config.env"
LOG_FILE="${HOME}/.config/container-webserver/webserver.log"
LAUNCHAGENT_FILE="${HOME}/Library/LaunchAgents/com.container.webserver.plist"

# Lade Konfiguration falls vorhanden
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Logging-Funktion
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Prüfe ob Container System läuft
check_system() {
    if ! command -v container &> /dev/null; then
        echo -e "${RED}Fehler: Container CLI nicht installiert${NC}"
        echo "Installiere mit: ./update-container.sh"
        exit 1
    fi

    if ! container system status &> /dev/null; then
        echo -e "${YELLOW}Container System wird gestartet...${NC}"
        container system start
        sleep 2
    fi
}

# Prüfe ob Update verfügbar ist
check_for_updates() {
    if [ "$AUTO_UPDATE" = "true" ]; then
        log "INFO" "Prüfe auf Container-System-Updates..."

        # Hole aktuelle Version
        CURRENT_VERSION=$(container system status 2>/dev/null | grep "version:" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")

        # Hole neueste Version von GitHub
        LATEST_VERSION=$(curl -s "https://api.github.com/repos/apple/container/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')

        if [ -n "$CURRENT_VERSION" ] && [ -n "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
            echo -e "${YELLOW}Update verfügbar: $CURRENT_VERSION → $LATEST_VERSION${NC}"
            read -p "Jetzt updaten? (j/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[JjYy]$ ]]; then
                log "INFO" "Starte Update von $CURRENT_VERSION auf $LATEST_VERSION"
                ./update-container.sh
                log "INFO" "Update abgeschlossen"
            fi
        else
            log "INFO" "Container System ist aktuell (Version: $CURRENT_VERSION)"
        fi
    fi
}

# Container-Status prüfen
get_container_status() {
    container list | grep -w "$CONTAINER_NAME" | awk '{print $5}' || echo "not_found"
}

# Container starten
start_container() {
    local status=$(get_container_status)

    if [ "$status" = "running" ]; then
        echo -e "${GREEN}Container '$CONTAINER_NAME' läuft bereits${NC}"
        return 0
    elif [ "$status" = "exited" ] || [ "$status" = "stopped" ]; then
        echo -e "${YELLOW}Starte existierenden Container '$CONTAINER_NAME'...${NC}"
        container start "$CONTAINER_NAME"
        log "INFO" "Container '$CONTAINER_NAME' gestartet"
    else
        echo -e "${YELLOW}Erstelle und starte neuen Container '$CONTAINER_NAME'...${NC}"

        # Baue Container-Befehl
        CMD="container run -d --name $CONTAINER_NAME"
        CMD="$CMD --cpus $CPUS --memory $MEMORY"
        CMD="$CMD -p $PORT_MAPPING"

        # Füge Volume-Mount hinzu falls konfiguriert
        if [ -n "$VOLUME_MOUNT" ]; then
            CMD="$CMD -v $VOLUME_MOUNT"
        fi

        CMD="$CMD $IMAGE_NAME"

        echo "Befehl: $CMD"
        eval $CMD

        log "INFO" "Container '$CONTAINER_NAME' erstellt und gestartet"
    fi

    # Warte kurz und prüfe Status
    sleep 2
    local new_status=$(get_container_status)

    if [ "$new_status" = "running" ]; then
        echo -e "${GREEN}✓ Container läuft erfolgreich${NC}"
        show_info
    else
        echo -e "${RED}✗ Container konnte nicht gestartet werden${NC}"
        container logs "$CONTAINER_NAME"
        exit 1
    fi
}

# Container stoppen
stop_container() {
    local status=$(get_container_status)

    if [ "$status" = "running" ]; then
        echo -e "${YELLOW}Stoppe Container '$CONTAINER_NAME'...${NC}"
        container stop "$CONTAINER_NAME"
        log "INFO" "Container '$CONTAINER_NAME' gestoppt"
        echo -e "${GREEN}✓ Container gestoppt${NC}"
    else
        echo -e "${YELLOW}Container '$CONTAINER_NAME' läuft nicht${NC}"
    fi
}

# Container neustarten
restart_container() {
    echo -e "${YELLOW}Starte Container '$CONTAINER_NAME' neu...${NC}"
    stop_container
    sleep 1
    start_container
}

# Container-Informationen anzeigen
show_info() {
    echo ""
    echo -e "${BLUE}=== Container-Informationen ===${NC}"
    container list | grep -w "$CONTAINER_NAME" || echo "Container nicht gefunden"

    # Extrahiere IP-Adresse
    local ip=$(container list | grep -w "$CONTAINER_NAME" | awk '{print $6}')

    if [ -n "$ip" ]; then
        echo ""
        echo -e "${GREEN}Webserver erreichbar unter:${NC}"
        echo "  - Container IP: http://$ip"

        # Parse Port-Mapping
        local host_port=$(echo "$PORT_MAPPING" | cut -d: -f1)
        if [[ "$host_port" =~ ^[0-9]+$ ]]; then
            echo "  - Localhost: http://localhost:$host_port"
        fi
    fi
    echo ""
}

# Container-Status anzeigen
show_status() {
    local status=$(get_container_status)

    echo -e "${BLUE}=== Status ===${NC}"
    echo "Container Name: $CONTAINER_NAME"
    echo "Image: $IMAGE_NAME"

    if [ "$status" = "running" ]; then
        echo -e "Status: ${GREEN}running${NC}"
        show_info
    elif [ "$status" = "not_found" ]; then
        echo -e "Status: ${YELLOW}nicht erstellt${NC}"
    else
        echo -e "Status: ${RED}$status${NC}"
    fi

    # System-Status
    echo ""
    container system status 2>/dev/null | head -4
}

# Container-Logs anzeigen
show_logs() {
    local follow=${1:-false}

    if [ "$follow" = "follow" ]; then
        echo "Verfolge Logs (Strg+C zum Beenden)..."
        container logs --follow "$CONTAINER_NAME"
    else
        container logs "$CONTAINER_NAME" | tail -n 50
    fi
}

# Auto-Start einrichten
setup_autostart() {
    echo -e "${YELLOW}Richte Auto-Start beim System-Boot ein...${NC}"

    # Erstelle LaunchAgent-Verzeichnis
    mkdir -p "$(dirname "$LAUNCHAGENT_FILE")"

    # Erstelle LaunchAgent plist
    cat > "$LAUNCHAGENT_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.container.webserver</string>

    <key>ProgramArguments</key>
    <array>
        <string>$(pwd)/webserver-manager.sh</string>
        <string>start</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>

    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>

    <key>WorkingDirectory</key>
    <string>$(pwd)</string>
</dict>
</plist>
EOF

    # Lade LaunchAgent
    launchctl unload "$LAUNCHAGENT_FILE" 2>/dev/null || true
    launchctl load "$LAUNCHAGENT_FILE"

    log "INFO" "Auto-Start eingerichtet"
    echo -e "${GREEN}✓ Auto-Start aktiviert${NC}"
    echo "LaunchAgent: $LAUNCHAGENT_FILE"
}

# Auto-Start deaktivieren
disable_autostart() {
    if [ -f "$LAUNCHAGENT_FILE" ]; then
        echo -e "${YELLOW}Deaktiviere Auto-Start...${NC}"
        launchctl unload "$LAUNCHAGENT_FILE" 2>/dev/null || true
        rm "$LAUNCHAGENT_FILE"
        log "INFO" "Auto-Start deaktiviert"
        echo -e "${GREEN}✓ Auto-Start deaktiviert${NC}"
    else
        echo -e "${YELLOW}Auto-Start ist nicht aktiviert${NC}"
    fi
}

# Konfiguration erstellen
create_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"

    cat > "$CONFIG_FILE" <<EOF
# Webserver Container Konfiguration

# Container-Name
CONTAINER_NAME="webserver"

# Docker Image (Beispiele: nginx:alpine, httpd:alpine, python:3-alpine)
IMAGE_NAME="nginx:alpine"

# Port-Mapping (Host:Container)
PORT_MAPPING="8080:80"

# Volume-Mount (optional, z.B. /host/path:/container/path)
VOLUME_MOUNT=""

# Ressourcen
MEMORY="2g"
CPUS="2"

# Auto-Update beim Start
AUTO_UPDATE="false"

# Restart-Policy
RESTART_POLICY="always"
EOF

    echo -e "${GREEN}✓ Konfigurationsdatei erstellt: $CONFIG_FILE${NC}"
    echo "Bearbeite die Datei und führe dann '$0 start' aus"
}

# Hilfe anzeigen
show_help() {
    cat <<EOF
${BLUE}Webserver Container Manager${NC}

${GREEN}Verwendung:${NC}
  $0 [BEFEHL] [OPTIONEN]

${GREEN}Befehle:${NC}
  start           Startet den Webserver-Container
  stop            Stoppt den Webserver-Container
  restart         Startet den Container neu
  status          Zeigt Container-Status an
  logs [follow]   Zeigt Container-Logs an (optional: follow)
  update          Prüft auf Container-System-Updates

  autostart       Aktiviert Auto-Start beim System-Boot
  disable         Deaktiviert Auto-Start

  config          Erstellt Konfigurationsdatei
  info            Zeigt Container-Informationen an

${GREEN}Beispiele:${NC}
  $0 start                    # Startet Webserver
  $0 logs follow              # Verfolgt Live-Logs
  $0 config                   # Erstellt Config
  $0 autostart                # Aktiviert Auto-Start

${GREEN}Konfiguration:${NC}
  Config-Datei: $CONFIG_FILE
  Log-Datei: $LOG_FILE
  LaunchAgent: $LAUNCHAGENT_FILE

${GREEN}Aktuelle Konfiguration:${NC}
  Container: $CONTAINER_NAME
  Image: $IMAGE_NAME
  Port: $PORT_MAPPING
  Memory: $MEMORY / CPUs: $CPUS
  Auto-Update: $AUTO_UPDATE

EOF
}

# Hauptlogik
main() {
    local command=${1:-help}

    # Erstelle Log-Verzeichnis
    mkdir -p "$(dirname "$LOG_FILE")"

    case "$command" in
        start)
            check_system
            check_for_updates
            start_container
            ;;
        stop)
            check_system
            stop_container
            ;;
        restart)
            check_system
            restart_container
            ;;
        status)
            check_system
            show_status
            ;;
        logs)
            check_system
            show_logs "${2:-}"
            ;;
        info)
            check_system
            show_info
            ;;
        update)
            check_for_updates
            ;;
        autostart)
            setup_autostart
            ;;
        disable)
            disable_autostart
            ;;
        config)
            create_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unbekannter Befehl: $command${NC}"
            echo "Verwende '$0 help' für Hilfe"
            exit 1
            ;;
    esac
}

# Script ausführen
main "$@"
