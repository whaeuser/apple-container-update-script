#!/bin/bash

# Test der Cleanup-Funktion und Trap-Mechanismen

echo "Test: Cleanup-Funktion und Trap-Handler"
echo "========================================"

# Cleanup-Funktion
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "✓ Cleanup aufgerufen, lösche: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Registriere Cleanup
trap cleanup EXIT INT TERM

# Test 1: Normaler Exit
echo ""
echo "Test 1: Normaler Exit mit Cleanup"
TEMP_DIR=$(mktemp -d /tmp/cleanup-test-XXXXXX)
echo "  Erstellt: $TEMP_DIR"

if [ -d "$TEMP_DIR" ]; then
    echo "  ✓ Verzeichnis existiert"
    touch "$TEMP_DIR/test.txt"
    echo "  ✓ Test-Datei erstellt"
fi

echo "  Skript beendet sich - Cleanup sollte automatisch erfolgen"
# EXIT trap wird hier automatisch aufgerufen
