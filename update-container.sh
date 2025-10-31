#!/bin/bash

set -e

# Cleanup-Funktion für automatisches Aufräumen bei Fehlern oder Abbruch
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "Räume temporäre Dateien auf..."
        rm -rf "$TEMP_DIR"
    fi
}

# Registriere Cleanup-Funktion für EXIT und Fehler-Signale
trap cleanup EXIT INT TERM

echo "=================================="
echo "Apple Container Update Script"
echo "=================================="
echo ""

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Prüfe ob auf Apple Silicon Mac
if [[ $(uname -m) != "arm64" ]]; then
    echo -e "${RED}Fehler: Dieses Tool benötigt einen Mac mit Apple Silicon${NC}"
    exit 1
fi

# Prüfe macOS Version
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
if [[ $MACOS_VERSION -lt 15 ]]; then
    echo -e "${RED}Fehler: Apple Container benötigt mindestens macOS 15${NC}"
    exit 1
fi
if [[ $MACOS_VERSION -lt 26 ]]; then
    echo -e "${YELLOW}Warnung: Für vollständige Features (z.B. Container-zu-Container Networking) wird macOS 26+ empfohlen${NC}"
fi

# 1. Stoppe laufendes System
echo -e "${YELLOW}[1/5] Stoppe Container System...${NC}"
if command -v container &> /dev/null; then
    container system stop || echo "Container System war nicht aktiv"
else
    echo "Container Tool noch nicht installiert, überspringe Stop-Befehl"
fi

# 2. Deinstalliere alte Version (behält Daten mit -k Flag)
echo -e "${YELLOW}[2/5] Deinstalliere alte Version (Daten werden behalten)...${NC}"
if [ -f "/usr/local/bin/uninstall-container.sh" ]; then
    sudo /usr/local/bin/uninstall-container.sh -k
    echo -e "${GREEN}Alte Version deinstalliert${NC}"
else
    echo "Keine vorherige Installation gefunden"
fi

# 3. Hole neueste Release-URL von GitHub
echo -e "${YELLOW}[3/5] Lade neuesten Installer von GitHub...${NC}"
LATEST_RELEASE_URL="https://github.com/apple/container/releases/latest"

# Hole aktuelle installierte Version (falls vorhanden)
CURRENT_VERSION=""
if command -v container &> /dev/null; then
    CURRENT_VERSION=$(container version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
    if [ -n "$CURRENT_VERSION" ]; then
        echo "Aktuell installierte Version: $CURRENT_VERSION"
    fi
fi

# Hole die neueste Release-Info
echo "Prüfe neueste verfügbare Version..."
RELEASE_JSON=$(curl -s "https://api.github.com/repos/apple/container/releases/latest")
# Suche nach der signierten Version (bevorzugt), sonst nimm die erste .pkg
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url.*signed\.pkg" | head -n1 | cut -d '"' -f 4)
if [ -z "$DOWNLOAD_URL" ]; then
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url.*\.pkg" | head -n1 | cut -d '"' -f 4)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Fehler: Konnte Download-URL nicht finden${NC}"
    echo "Bitte manuell herunterladen von: $LATEST_RELEASE_URL"
    exit 1
fi

# Validiere Download-URL (muss von github.com sein)
if [[ ! "$DOWNLOAD_URL" =~ ^https://github\.com/ ]]; then
    echo -e "${RED}Fehler: Ungültige Download-URL. Muss von github.com sein${NC}"
    echo "Erhaltene URL: $DOWNLOAD_URL"
    exit 1
fi

# Extrahiere neue Version aus Release-Info
NEW_VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')

if [ -n "$NEW_VERSION" ]; then
    echo "Neueste verfügbare Version: $NEW_VERSION"

    # Vergleiche Versionen falls aktuelle Version bekannt ist
    if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
        echo -e "${GREEN}Sie verwenden bereits die neueste Version ($CURRENT_VERSION)${NC}"
        read -p "Trotzdem neu installieren? (j/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
            echo "Installation abgebrochen"
            exit 0
        fi
    fi
else
    echo -e "${YELLOW}Warnung: Konnte Versions-Information nicht extrahieren${NC}"
fi

PKG_NAME=$(basename "$DOWNLOAD_URL")
# Verwende sichere temporäre Dateien
TEMP_DIR=$(mktemp -d /tmp/container-update-XXXXXX)
DOWNLOAD_PATH="$TEMP_DIR/$PKG_NAME"

# Prüfe verfügbaren Festplattenspeicher (mindestens 500 MB)
REQUIRED_SPACE_MB=500
AVAILABLE_SPACE=$(df -m "$TEMP_DIR" | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_MB" ]; then
    echo -e "${RED}Fehler: Nicht genug Speicherplatz. Benötigt: ${REQUIRED_SPACE_MB}MB, Verfügbar: ${AVAILABLE_SPACE}MB${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Lade herunter: $PKG_NAME"
curl -L -# -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL"

if [ ! -f "$DOWNLOAD_PATH" ]; then
    echo -e "${RED}Fehler: Download fehlgeschlagen${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}Download abgeschlossen${NC}"

# Prüfe SHA256-Checksumme falls verfügbar
echo -e "${YELLOW}Prüfe Integrität des Downloads...${NC}"
CHECKSUM_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url.*sha256" | head -n1 | cut -d '"' -f 4)

if [ -n "$CHECKSUM_URL" ]; then
    echo "Lade Checksumme herunter..."
    curl -sL "$CHECKSUM_URL" -o "$TEMP_DIR/checksums.txt"

    if [ -f "$TEMP_DIR/checksums.txt" ]; then
        # Filtere nur die Zeile für unser Package
        EXPECTED_CHECKSUM=$(grep "$PKG_NAME" "$TEMP_DIR/checksums.txt" | awk '{print $1}')

        if [ -n "$EXPECTED_CHECKSUM" ]; then
            ACTUAL_CHECKSUM=$(shasum -a 256 "$DOWNLOAD_PATH" | awk '{print $1}')

            if [ "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
                echo -e "${GREEN}✓ Checksumme erfolgreich validiert${NC}"
            else
                echo -e "${RED}Fehler: Checksumme stimmt nicht überein!${NC}"
                echo "Erwartet: $EXPECTED_CHECKSUM"
                echo "Erhalten: $ACTUAL_CHECKSUM"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
        else
            echo -e "${YELLOW}Warnung: Checksumme für $PKG_NAME nicht in der Datei gefunden${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Warnung: Keine Checksummen-Datei verfügbar${NC}"
fi

# Verifiziere Paket-Signatur
echo -e "${YELLOW}Verifiziere Paket-Signatur...${NC}"
SIGNATURE_CHECK=$(pkgutil --check-signature "$DOWNLOAD_PATH" 2>&1)

if echo "$SIGNATURE_CHECK" | grep -q "signed by a developer certificate"; then
    echo -e "${GREEN}✓ Paket-Signatur erfolgreich verifiziert${NC}"
    # Zeige Signatur-Details
    echo "$SIGNATURE_CHECK" | grep -E "(signed by|Developer ID|Authority)" | head -3
elif echo "$SIGNATURE_CHECK" | grep -q "signed by a certificate"; then
    echo -e "${GREEN}✓ Paket ist signiert${NC}"
else
    echo -e "${RED}Warnung: Paket-Signatur konnte nicht verifiziert werden!${NC}"
    echo "$SIGNATURE_CHECK"
    read -p "Trotzdem fortfahren? (j/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
        echo "Installation abgebrochen"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# 4. Installiere neue Version
echo -e "${YELLOW}[4/5] Installiere neue Version...${NC}"
echo "Administratorrechte werden benötigt..."
sudo installer -pkg "$DOWNLOAD_PATH" -target /

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Installation erfolgreich${NC}"
else
    echo -e "${RED}Installation fehlgeschlagen${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 5. Starte Container System
echo -e "${YELLOW}[5/5] Starte Container System...${NC}"
container system start

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Container System gestartet${NC}"
else
    echo -e "${RED}Fehler beim Starten des Container Systems${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup temporäres Verzeichnis
echo "Räume temporäre Dateien auf..."
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}=================================="
echo "Update erfolgreich abgeschlossen!"
echo "==================================${NC}"
echo ""
echo "Version:"
container version 2>/dev/null || echo "Verwende 'container version' um Version zu prüfen"
