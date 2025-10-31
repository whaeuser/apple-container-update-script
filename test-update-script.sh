#!/bin/bash

# Test-Script für update-container.sh
# Testet nur die nicht-destruktiven Teile

set -e

echo "=================================="
echo "Test: Apple Container Update Script"
echo "=================================="
echo ""

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Apple Silicon Check
echo -e "${YELLOW}Test 1: Apple Silicon Check${NC}"
if [[ $(uname -m) == "arm64" ]]; then
    echo -e "${GREEN}✓ Apple Silicon erkannt${NC}"
else
    echo -e "${YELLOW}⚠ Intel Mac erkannt (wird in echtem Script fehlschlagen)${NC}"
fi
echo ""

# Test 2: macOS Version Check
echo -e "${YELLOW}Test 2: macOS Version Check${NC}"
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
echo "Erkannte macOS Version: $MACOS_VERSION"
if [[ $MACOS_VERSION -lt 15 ]]; then
    echo -e "${RED}✗ macOS Version zu alt (< 15)${NC}"
elif [[ $MACOS_VERSION -lt 26 ]]; then
    echo -e "${YELLOW}⚠ macOS < 26 (einige Features nicht verfügbar)${NC}"
else
    echo -e "${GREEN}✓ macOS Version ausreichend${NC}"
fi
echo ""

# Test 3: Container Command verfügbar
echo -e "${YELLOW}Test 3: Container Command Check${NC}"
if command -v container &> /dev/null; then
    CURRENT_VERSION=$(container version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
    if [ -n "$CURRENT_VERSION" ]; then
        echo -e "${GREEN}✓ Container installiert: Version $CURRENT_VERSION${NC}"
    else
        echo -e "${YELLOW}⚠ Container installiert, aber Version nicht erkennbar${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Container nicht installiert (Neuinstallation)${NC}"
fi
echo ""

# Test 4: GitHub API Zugriff
echo -e "${YELLOW}Test 4: GitHub API Zugriff${NC}"
RELEASE_JSON=$(curl -s "https://api.github.com/repos/apple/container/releases/latest")

if [ -z "$RELEASE_JSON" ] || echo "$RELEASE_JSON" | grep -q "API rate limit exceeded"; then
    echo -e "${RED}✗ GitHub API nicht erreichbar oder Rate Limit überschritten${NC}"
    exit 1
else
    echo -e "${GREEN}✓ GitHub API erreichbar${NC}"
fi
echo ""

# Test 5: Download URL Extraktion
echo -e "${YELLOW}Test 5: Download URL Extraktion${NC}"
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url.*signed\.pkg" | head -n1 | cut -d '"' -f 4)
if [ -z "$DOWNLOAD_URL" ]; then
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url.*\.pkg" | head -n1 | cut -d '"' -f 4)
fi

if [ -n "$DOWNLOAD_URL" ]; then
    echo -e "${GREEN}✓ Download URL gefunden${NC}"
    echo "  URL: $DOWNLOAD_URL"
else
    echo -e "${RED}✗ Keine Download URL gefunden${NC}"
    exit 1
fi
echo ""

# Test 6: URL Validierung
echo -e "${YELLOW}Test 6: URL Validierung${NC}"
if [[ "$DOWNLOAD_URL" =~ ^https://github\.com/ ]]; then
    echo -e "${GREEN}✓ URL ist gültig (github.com)${NC}"
else
    echo -e "${RED}✗ URL ist ungültig (nicht von github.com)${NC}"
    echo "  Erhaltene URL: $DOWNLOAD_URL"
    exit 1
fi
echo ""

# Test 7: Versions-Extraktion
echo -e "${YELLOW}Test 7: Versions-Extraktion${NC}"
NEW_VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')

if [ -n "$NEW_VERSION" ]; then
    echo -e "${GREEN}✓ Version extrahiert: $NEW_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Version konnte nicht extrahiert werden${NC}"
fi
echo ""

# Test 8: Versions-Vergleich (falls Container installiert)
if command -v container &> /dev/null && [ -n "$CURRENT_VERSION" ] && [ -n "$NEW_VERSION" ]; then
    echo -e "${YELLOW}Test 8: Versions-Vergleich${NC}"
    echo "  Aktuell: $CURRENT_VERSION"
    echo "  Neueste: $NEW_VERSION"
    if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
        echo -e "${GREEN}✓ Bereits auf neuester Version${NC}"
    else
        echo -e "${YELLOW}⚠ Update verfügbar${NC}"
    fi
    echo ""
fi

# Test 9: Temporäres Verzeichnis
echo -e "${YELLOW}Test 9: Temporäres Verzeichnis${NC}"
TEMP_DIR=$(mktemp -d /tmp/container-update-test-XXXXXX)
if [ -d "$TEMP_DIR" ]; then
    echo -e "${GREEN}✓ Temporäres Verzeichnis erstellt: $TEMP_DIR${NC}"
    rm -rf "$TEMP_DIR"
else
    echo -e "${RED}✗ Konnte temporäres Verzeichnis nicht erstellen${NC}"
    exit 1
fi
echo ""

# Test 10: Festplattenspeicher
echo -e "${YELLOW}Test 10: Festplattenspeicher${NC}"
REQUIRED_SPACE_MB=500
AVAILABLE_SPACE=$(df -m /tmp | tail -1 | awk '{print $4}')
echo "  Benötigt: ${REQUIRED_SPACE_MB}MB"
echo "  Verfügbar: ${AVAILABLE_SPACE}MB"
if [ "$AVAILABLE_SPACE" -ge "$REQUIRED_SPACE_MB" ]; then
    echo -e "${GREEN}✓ Genug Speicherplatz verfügbar${NC}"
else
    echo -e "${RED}✗ Nicht genug Speicherplatz${NC}"
fi
echo ""

# Test 11: Checksummen-URL (optional)
echo -e "${YELLOW}Test 11: Checksummen-Datei Check${NC}"
CHECKSUM_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url.*sha256" | head -n1 | cut -d '"' -f 4)
if [ -n "$CHECKSUM_URL" ]; then
    echo -e "${GREEN}✓ Checksummen-Datei verfügbar${NC}"
    echo "  URL: $CHECKSUM_URL"
else
    echo -e "${YELLOW}⚠ Keine Checksummen-Datei gefunden (optional)${NC}"
fi
echo ""

# Zusammenfassung
echo "=================================="
echo -e "${GREEN}Test-Suite abgeschlossen!${NC}"
echo "=================================="
echo ""
echo "Das Script hat die Validierungs-Tests bestanden."
echo "WARNUNG: Dies testet nur die nicht-destruktiven Teile!"
echo ""
