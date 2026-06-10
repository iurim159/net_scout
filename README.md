# NetScout LAN 🔍

Un'applicazione Flutter per **scoprire e mappare dispositivi sulla rete locale** con stile moderno e interfaccia intuitiva.

## 🎯 Cosa fa

- **Scansione automatica della rete locale** (Wi-Fi, Ethernet)
- **Rilevamento dispositivi attivi** sulla subnet
- **Identificazione tipo dispositivo** (Router, PC, Smartphone, Laptop)
- **Scan porte aperte** su ogni dispositivo trovato
- **Interfaccia dark mode** con tema Material 3
- **Funziona su**: Windows, Android, macOS, Linux, Web

## 🚀 Funzionalità principali

### 1. Selezione automatica della rete
- Identifica automaticamente la rete Wi-Fi/Ethernet corretta
- Esclude interfacce di sistema, VPN e virtualizzazione
- Priorità massima a Wi-Fi reale vs connessioni virtuali

### 2. Scansione rapida con Isolate
- Utilizza Dart Isolate per non bloccare l'UI
- Scansione parallela di 254 IP per massima velocità
- Stream in tempo reale dei dispositivi trovati

### 3. Rilevamento dispositivi
- **Socket connection** su porte comuni (80, 443, 22, 23, 135, 445)
- **Reverse DNS lookup** per nome hostname
- **Classificazione automatica**: Router, PC, Smartphone, Laptop

### 4. Scansione porte
Controlla apertura su porte comuni:
- 20-25: FTP, SMTP
- 53: DNS
- 80, 443: HTTP/HTTPS
- 110, 143: POP3, IMAP
- 22, 23: SSH, Telnet
- 135, 445: SMB (Windows)

## 📁 Struttura progetto

```
lib/
├── main.dart              # UI principale (ScanScreen, NetScoutApp)
├── network_service.dart   # Core: scansione, rilevamento, porte
└── device_model.dart      # Modello dati dispositivo
```

## 🔧 Come usare

### Su Windows
```bash
flutter run
```

### Build APK per Android
```bash
flutter clean
flutter pub get
flutter build apk --release
```

L'APK sarà in: `build/app/outputs/flutter-apk/app-release.apk`

## 📋 Requisiti

- Flutter 3.0+
- Dart 3.0+
- Permessi di rete attiva
- Connessione a una rete locale

### Permessi Android (già configurati)
- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- `android.permission.CHANGE_NETWORK_STATE`

## 🐛 Risoluzione problemi

### "Errore: Assicurati di essere connesso al Wi-Fi"
- ✅ Connettiti a una rete Wi-Fi o Ethernet
- ✅ Disabilita VPN
- ✅ Controlla i permessi di rete

### Subnet sbagliato rilevato (es. 10.114.x.x)
- Il sistema ora esclude automaticamente interfacce virtuali
- Se ancora problematico, controlla `_scoreLocalInterface()` in `network_service.dart`

### Solo DNS (porta 53) trovato
- La subnet rilevata è sbagliata
- Connettiti direttamente alla rete Wi-Fi primaria
- Disabilita VPN e hotspot

## 📱 Screenshot

(Da aggiungere quando disponibile)

## 🔄 Flusso scansione

```
1. Tap "Scansiona"
2. Identifica subnet Wi-Fi → 192.168.1.0/24
3. Genera IP list (1-254)
4. Parallelize 254 socket tests
5. Stream risultati real-time
6. Per ogni IP trovato: scan porte
7. Visualizza lista dispositivi
```

## 📊 Performance

- **Tempo medio**: 10-30 secondi per subnet completa
- **Processamento parallelo**: 254 IP simultanei
- **Memory**: <50MB per UI + scansione
- **Battery**: Ottimizzato con timeout aggressivi (100-150ms)

## 🔐 Privacy & Sicurezza

⚠️ **Importante**:
- Usa su reti che possiedi/hai permesso di scansionare
- Non usare per hacking/scanning non autorizzato
- I dati rimangono locali, nessun invio online
- Timeout rapidi per ridurre impatto rete

## 🎓 Tecnologie utilizzate

- **Flutter**: Framework UI
- **Dart**: Linguaggio
- **Isolate**: Threading nativo
- **Socket API**: Network scanning
- **NetworkInterface**: Rilevamento rete
- **Material 3**: Design system
