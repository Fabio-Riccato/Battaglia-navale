# Progetto Battaglia Navale Online

Questo progetto consiste in un'applicazione per giocare alla Battaglia Navale in rete locale tramite protocollo TCP. Il sistema e composto da un server centrale che coordina la partita e da un'applicazione client sviluppata in Flutter.

## Struttura del progetto

Il software e diviso in due parti principali:

- Server (Dart): Gestisce le connessioni dei client, la logica dei turni, il controllo dei colpi e determina la vittoria.
- Client (App Flutter): Fornisce l'interfaccia grafica per il posizionamento delle navi e la gestione della battaglia.

## Requisiti tecnici
- Linguaggio: Dart

- Framework: Flutter

- Comunicazione: Socket TCP

- Scambio dati: Stringhe formattate e oggetti JSON

## Istruzioni per l'uso
- Avvio del Server: Eseguire il file server.dart tramite il comando "dart server.dart" da terminale. Il server si mettera in ascolto sulla porta 4040.

- Connessione del Client: Aprire l'app sul dispositivo o emulatore. Inserire il proprio nickname e l'indirizzo IP del computer su cui e attivo il server. Premere su Connetti.

- Svolgimento del gioco: Una volta che due giocatori sono connessi e hanno premuto su Trova Partita, si passa alla fase di posizionamento delle navi. Dopo aver confermato la propria flotta, il server dara il via alla battaglia. I colpi vengono assegnati in tempo reale e il turno passa all'avversario in caso di errore (acqua).

## Funzionalita implementate
- Gestione automatica dei turni.

- Rilevamento delle navi affondate.

- Adattamento dinamico della griglia di gioco per diversi schermi Android.

- Gestione della disconnessione: se un utente abbandona, l'altro vince automaticamente.

- Notifiche a schermo tramite popup per i risultati della partita.
