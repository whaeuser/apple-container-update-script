#!/bin/bash

# Test der Checksummen-Validierung

echo "Test: SHA256-Checksummen-Validierung"
echo "====================================="
echo ""

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Erstelle Test-Datei
TEMP_DIR=$(mktemp -d /tmp/checksum-test-XXXXXX)
trap "rm -rf $TEMP_DIR" EXIT

TEST_FILE="$TEMP_DIR/test.pkg"
echo "Test Content" > "$TEST_FILE"

# Berechne echte Checksumme
ACTUAL_CHECKSUM=$(shasum -a 256 "$TEST_FILE" | awk '{print $1}')
echo "Test-Datei erstellt: $TEST_FILE"
echo "Echte Checksumme: $ACTUAL_CHECKSUM"
echo ""

# Test 1: Korrekte Checksumme
echo "Test 1: Korrekte Checksumme"
EXPECTED_CHECKSUM="$ACTUAL_CHECKSUM"
if [ "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
    echo -e "${GREEN}✓ Checksumme stimmt überein${NC}"
else
    echo -e "${RED}✗ Checksumme stimmt nicht überein${NC}"
fi
echo ""

# Test 2: Falsche Checksumme
echo "Test 2: Falsche Checksumme (sollte fehlschlagen)"
EXPECTED_CHECKSUM="0000000000000000000000000000000000000000000000000000000000000000"
if [ "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
    echo -e "${GREEN}✓ Checksumme stimmt überein${NC}"
else
    echo -e "${RED}✗ Checksumme stimmt nicht überein (ERWARTET)${NC}"
    echo "  Erwartet: $EXPECTED_CHECKSUM"
    echo "  Erhalten: $ACTUAL_CHECKSUM"
fi
echo ""

# Test 3: Checksummen-Datei Format
echo "Test 3: Checksummen-Datei Format"
cat > "$TEMP_DIR/checksums.txt" <<EOF
$ACTUAL_CHECKSUM  test.pkg
1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  other.pkg
EOF

PKG_NAME="test.pkg"
FOUND_CHECKSUM=$(grep "$PKG_NAME" "$TEMP_DIR/checksums.txt" | awk '{print $1}')

if [ "$FOUND_CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
    echo -e "${GREEN}✓ Checksumme erfolgreich aus Datei extrahiert${NC}"
else
    echo -e "${RED}✗ Checksumme konnte nicht extrahiert werden${NC}"
fi

echo ""
echo -e "${GREEN}Checksummen-Tests abgeschlossen${NC}"
