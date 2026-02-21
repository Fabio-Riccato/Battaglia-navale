# Battaglia Navale (Client + Server)

Monorepo con **due progetti Flutter**:
- `client/`: app giocatore (UI di posizionamento e battaglia)
- `server/`: app server (logica partite + gestione connessioni TCP)

## Struttura

- `client/lib/` → schermate e logica lato giocatore
- `server/lib/` → logica server e servizio background

## Prerequisiti

- Flutter SDK installato e funzionante (`flutter doctor -v`)
- Un solo ambiente Flutter nel `PATH` (consigliato)
- Su Windows: PowerShell o terminale con `flutter` e `dart` disponibili

## Setup rapido (Windows)

1. Verifica toolchain:
   ```powershell
   flutter --version
   dart --version
   flutter doctor -v
   ```

2. Installa dipendenze di entrambi i progetti:
   ```powershell
   cd .\client
   flutter pub get

   cd ..\server
   flutter pub get
   ```

## Esecuzione

### Avvio server
```powershell
cd .\server
flutter run
```

### Avvio client
```powershell
cd .\client
flutter run
```

> Suggerimento: avvia prima il server, poi due istanze client.

## Test e qualità codice

### Client
```powershell
cd .\client
flutter analyze
flutter test
```

### Server
```powershell
cd .\server
flutter analyze
flutter test
```

## Nota importante su SDK (client/server)

Essendo due progetti separati, ciascuno ha il proprio vincolo in `pubspec.yaml` (`environment > sdk`).
Se hai errori di compatibilità:

- usa una versione Flutter sufficientemente recente per soddisfare **entrambi** i progetti
- in alternativa allinea i vincoli SDK tra `client/pubspec.yaml` e `server/pubspec.yaml`

## Troubleshooting comune (Windows)

- `flutter` non trovato:
  - aggiungi `C:\src\flutter\bin` al `PATH`
  - riapri il terminale
- dipendenze non risolvibili:
  - esegui `flutter clean` e poi `flutter pub get` nella cartella del progetto interessato
- mismatch SDK tra client e server:
  - verifica i campi `environment.sdk` nei due `pubspec.yaml`

