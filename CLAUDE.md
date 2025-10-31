# Apple Container Technologie

Quelle: https://github.com/apple/container

## Projektbeschreibung

Apple Container ist ein Swift-basiertes Tool für macOS, das es ermöglicht, Linux-Container als leichtgewichtige virtuelle Maschinen auf dem Mac zu erstellen und auszuführen. Die Anwendung ist für Apple Silicon optimiert und nutzt das Containerization Swift Package für die zugrundeliegenden Container-Management-Operationen.

## Hauptmerkmale & Funktionen

### Container Image Standards
- Arbeitet mit OCI-kompatiblen Container Images
- Ermöglicht das Pullen von Standard-Registries
- Unterstützt das Erstellen von benutzerdefinierten Images
- Push-Funktionalität zu jeder OCI-kompatiblen Plattform

### Technische Grundlage
- Basiert auf dem Containerization Swift Package
- Low-Level Container-, Image- und Prozess-Management
- Robuste Infrastruktur für Virtualisierungsoperationen

## Systemanforderungen

- **Hardware**: Mac mit Apple Silicon Prozessor
- **Betriebssystem**: macOS 26 (erforderlich für neue Features und Verbesserungen bei Virtualisierung und Netzwerk)
- **Build**: Dokumentation verfügbar in BUILDING.md

## Installation & Verwaltung

### Installation
1. Signiertes Installationspaket von der GitHub Releases-Seite herunterladen
2. Paket per Doppelklick öffnen
3. Administrator-Zugangsdaten eingeben
4. Service starten mit: `container system start`

### Deinstallation
Das `uninstall-container.sh` Script entfernt die Anwendung:
- `-k` Flag: Behält Benutzerdaten bei
- `-d` Flag: Entfernt alle Daten vollständig

## Dokumentation & Ressourcen

Das Projekt bietet:
- Geführtes Tutorial zum Erstellen und Deployen von Webserver-Images
- Feature-Nutzungsdokumentation
- Technische Übersicht und Architektur-Details
- Vollständige Befehlsreferenz
- API-Dokumentationsportal

## Projektstatus

Aktuell in aktiver Entwicklung. Stabilität ist nur innerhalb von Patch-Versionen garantiert, bis Version 1.0.0 erreicht wird.

---

## How-To: Befehle & Anleitungen

Quelle: https://github.com/apple/container/blob/main/docs/how-to.md

### Ressourcen-Konfiguration

#### Memory und CPU für Container
Container mit benutzerdefinierten Ressourcenlimits ausführen:
```bash
container run --rm --cpus 8 --memory 32g image_name
```
Standard: 1GB RAM / 4 CPUs

#### Builder VM Konfiguration
Builder mit erhöhten Ressourcen starten:
```bash
container builder start --cpus 8 --memory 32g
```
**Hinweis**: Um bestehende Builder-Einstellungen zu ändern, muss der Builder erst gestoppt und gelöscht werden.

### Datei- & Netzwerk-Operationen

#### Volume Mounting
Host-Verzeichnisse teilen:
```bash
# Variante 1: --volume
container run --volume /host/path:/container/path image_name

# Variante 2: --mount
container run --mount source=/host/path,target=/container/path image_name
```

#### Port Forwarding
Localhost-Traffic weiterleiten:
```bash
container run -p 127.0.0.1:8080:8000 image:tag
```
Syntax: `[host-ip:]host-port:container-port[/protocol]`

#### SSH-Zugriff
SSH-Socket-Forwarding aktivieren:
```bash
container run --ssh image_name
```
Mounted automatisch den Authentication-Socket für Git-Operationen mit SSH-Keys.

#### Benutzerdefinierte MAC-Adresse
MAC-Adresse zuweisen:
```bash
container run --network default,mac=02:42:ac:11:00:02 image_name
```
Format: XX:XX:XX:XX:XX:XX (mit Doppelpunkten oder Bindestrichen)

### Multi-Architektur & Netzwerk

#### Multiplatform Images
Für mehrere Architekturen bauen:
```bash
container build --arch arm64 --arch amd64 --tag registry/image:tag .
```

#### Isolierte Netzwerke
Separate Netzwerke erstellen und verwenden:
```bash
# Netzwerk erstellen
container network create foo

# Netzwerke auflisten
container network list

# Container mit Netzwerk verbinden
container run --network foo image_name
```

### Inspektion & Logging

#### Container-Details
Ressourcen inspizieren:
```bash
container inspect container_name | jq
```

#### Logs anzeigen
Container-Output anzeigen:
```bash
# Container-Logs
container logs container_name

# VM Boot-Logs
container logs --boot container_name
```

#### System-Eigenschaften
Konfiguration auflisten und ändern:
```bash
# Eigenschaften auflisten
container system property list

# Rosetta deaktivieren
container system property set build.rosetta false
```

#### System-Logs
Services überwachen:
```bash
container system logs | tail -n
```

### Shell Completion

Completion-Skripte generieren:
```bash
container --generate-completion-script [zsh|bash|fish]
```

**Zsh**: Kopieren nach `~/.oh-my-zsh/completions/_container` oder `~/.zsh/completion/_container`

**Bash**: Kopieren nach `/opt/homebrew/etc/bash_completion.d/container` oder `~/.bash_completions/container`

**Fish**: Kopieren nach `~/.config/fish/completions/container.fish`

---

## Befehls-Referenz

Quelle: https://github.com/apple/container/blob/main/docs/command-reference.md

### Kern-Befehle

#### container run
Führt einen Container von einem Image aus, mit optionaler Befehlsausführung. Läuft standardmäßig im Vordergrund; stdin ist geschlossen, außer `-i/--interactive` ist angegeben.

**Wichtige Flags**: `-e/--env`, `--env-file`, `-i/--interactive`, `-t/--tty`, `-u/--user`, `-c/--cpus`, `-m/--memory`, `-d/--detach`, `--name`, `-p/--publish`, `-v/--volume`, `--network`, `--entrypoint`, `--mount`, `--tmpfs`

#### container build
Erstellt OCI-Images aus Dockerfile/Containerfile mit BuildKit-Isolation. Sucht zuerst nach Dockerfile, dann nach Containerfile.

**Wichtige Flags**: `-t/--tag`, `-f/--file`, `--build-arg`, `-c/--cpus`, `-m/--memory`, `--target`, `--no-cache`, `--platform`, `-a/--arch`, `--os`

### Container-Verwaltung

- **container create** - Initialisiert Container ohne zu starten
- **container start** - Startet gestoppten Container; unterstützt `--attach`, `--interactive`
- **container stop** - Beendet Container sauber (Standard-Signal: SIGTERM, Timeout: 5s)
- **container kill** - Beendet Container sofort (Standard-Signal: KILL)
- **container delete (rm)** - Entfernt Container; `-f/--force` überschreibt laufenden Status
- **container list (ls)** - Zeigt Container an; `--all` inkl. gestoppte; Formate: json/table
- **container exec** - Führt Befehle in laufenden Containern aus mit Environment/User-Kontrolle
- **container logs** - Ruft Container-Output ab; `--follow` streamt; `--boot` zeigt Startup-Logs
- **container inspect** - Gibt detaillierte JSON Container-Informationen aus

### Image-Verwaltung

- **container image list (ls)** - Listet lokale Images auf mit optionaler verbose/JSON-Ausgabe
- **container image pull** - Lädt Images von Registries herunter; unterstützt Plattform-Auswahl
- **container image push** - Lädt Images zu Registries hoch mit Plattform-Filterung
- **container image save** - Exportiert Images als tar-Archive für Offline-Transport
- **container image load** - Importiert tar-Archive via `--input`
- **container image tag** - Wendet zusätzliche Tags auf bestehende Images an
- **container image delete (rm)** - Entfernt lokale Images
- **container image prune** - Bereinigt ungenutzte Images
- **container image inspect** - Zeigt detaillierte Image-Metadaten an

### Builder, Netzwerk & Volume-Verwaltung

- **container builder** - Befehle: `start`, `status`, `stop`, `delete (rm)`
- **container network** - Nur macOS 26+: `create`, `delete (rm)`, `list (ls)`, `inspect`
- **container volume** - Befehle: `create`, `delete (rm)`, `list (ls)`, `inspect`

### Registry & System-Verwaltung

- **container registry login/logout** - Authentifizierungs-Management
- **container system** - Befehle: `start`, `stop`, `status`, `logs`, DNS-Konfiguration, Kernel-Einstellungen, Property-Management

---

## Tutorial: Containerized Application erstellen

Quelle: https://github.com/apple/container/blob/main/docs/tutorial.md

### Erste Schritte

**Service initialisieren:**
```bash
container system start
```

Das System fordert bei Bedarf zur Installation eines Linux-Kernels auf. Funktionalität überprüfen:
```bash
container list --all
```

**Hilfe-Dokumentation aufrufen:**
```bash
container --help
```

**Befehls-Abkürzungen:** Befehle können verkürzt werden (z.B. `container ls` für `list`, `-a` für `--all`).

**Optionales DNS-Setup:** Für lokale Domain-Auflösung:
```bash
sudo container system dns create test
container system property set dns.domain test
```

Dies ermöglicht Zugriff auf Container via Hostnamen wie `my-web-server.test`.

### Container Images bauen

**Projektverzeichnis erstellen:**
```bash
mkdir web-test && cd web-test
```

**Dockerfile schreiben** mit einem Python-Base-Image, das eine einfache HTML-Seite ausliefert:
- Verwendet Alpine Linux Python-Image als Basis
- Erstellt `/content` Arbeitsverzeichnis
- Installiert `curl` Utility
- Generiert einfache HTML-Landingpage
- Konfiguriert Python HTTP-Server auf Port 80

**Image bauen:**
```bash
container build --tag web-test --file Dockerfile .
```

Fertigstellung überprüfen mit `container image list`.

### Container ausführen

**Webserver-Container starten:**
```bash
container run --name my-web-server --detach --rm web-test
```

`--detach` führt im Hintergrund aus; `--rm` entfernt automatisch beim Beenden.

**Laufende Container auflisten:**
```bash
container ls
```

Zeigt die zugewiesene IP-Adresse des Containers (z.B. `192.168.64.3`).

**Auf Webserver zugreifen:**
```bash
open http://192.168.64.3
```

Oder mit konfigurierter Domain: `open http://my-web-server.test`

**Befehle in laufenden Containern ausführen:**
```bash
container exec my-web-server ls /content
```

**Interaktiver Shell-Zugriff:**
```bash
container exec --tty --interactive my-web-server sh
```

Die `-ti` Flags ermöglichen Terminal-Interaktion mit dem Container.

**Container-zu-Container-Kommunikation:**
```bash
container run -it --rm web-test curl http://192.168.64.3
```

Demonstriert Zugriff auf Services eines Containers von einem anderen.

### Images veröffentlichen

**Bei Registry authentifizieren:**
```bash
container registry login some-registry.example.com
```

**Image für Veröffentlichung taggen:**
```bash
container image tag web-test some-registry.example.com/fido/web-test:latest
```

**Zu Registry pushen:**
```bash
container image push some-registry.example.com/fido/web-test:latest
```

**Validierung durch Pullen und Ausführen:**
```bash
container stop my-web-server
container image delete web-test some-registry.example.com/fido/web-test:latest
container run --name my-web-server --detach --rm some-registry.example.com/fido/web-test:latest
```

### Aufräumen

**Laufende Container stoppen:**
```bash
container stop my-web-server
```

**Services herunterfahren:**
```bash
container system stop
```

**Hinweis:** Container-zu-Container-Networking benötigt macOS 26; dieses Feature ist auf macOS 15 nicht verfügbar.
