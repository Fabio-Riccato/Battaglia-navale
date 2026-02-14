import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

// --- LOGICA SERVER ---

ServerSocket? _serverSocket;
final List<Socket> codaGiocatori = [];
final Set<Socket> inAttesaDiGiocare = {};
final List<Partita> partite = [];
final Map<Socket, String> tempNicknames = {};

Future<void> avviaServerLogica() async {
  if (_serverSocket != null) return;

  try {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
    print('Server Battaglia Navale avviato sulla porta 4040');

    _serverSocket!.listen((Socket client) {
      print('Nuovo client connesso: ${client.remoteAddress.address}');
      gestisciClient(client);
    });
  } catch (e) {
    print("Errore avvio server: $e");
  }
}

void fermaServerLogica() {
  _serverSocket?.close();
  _serverSocket = null;

  for (var s in codaGiocatori) {
    try { s.close(); } catch (_) {}
  }
  codaGiocatori.clear();

  for (var s in inAttesaDiGiocare) {
    try { s.close(); } catch (_) {}
  }
  inAttesaDiGiocare.clear();

  for (var p in partite) {
    try { p.giocatore1.close(); } catch (_) {}
    try { p.giocatore2.close(); } catch (_) {}
  }
  partite.clear();
  tempNicknames.clear();

  print("Server spento e connessioni chiuse.");
}

enum StatoPartita { attesaGiocatori, posizionamento, inGioco, terminata }

class Partita {
  Socket giocatore1;
  Socket giocatore2;
  String nick1 = "Giocatore 1";
  String nick2 = "Giocatore 2";
  StatoPartita stato = StatoPartita.attesaGiocatori;
  bool pos1Pronto = false;
  bool pos2Pronto = false;
  List<List<int>> navi1 = [];
  List<List<int>> navi2 = [];
  Set<int> colpi1 = {};
  Set<int> colpi2 = {};
  int turno = 1;

  Partita(this.giocatore1, this.giocatore2);

  bool contiene(Socket s) => s == giocatore1 || s == giocatore2;
  Socket avversario(Socket s) => s == giocatore1 ? giocatore2 : giocatore1;
  int indice(Socket s) => s == giocatore1 ? 1 : 2;
}

void gestisciClient(Socket socket) {
  socket.listen(
        (data) {
      final messaggioCompleto = utf8.decode(data);
      for (final line in messaggioCompleto.split('\n')) {
        if (line.trim().isEmpty) continue;
        gestisciMessaggio(socket, line.trim());
      }
    },
    onDone: () {
      print('Client disconnesso: ${socket.remoteAddress.address}');
      gestisciDisconnessione(socket);
    },
    onError: (error) {
      print('Errore client ${socket.remoteAddress.address}: $error');
      gestisciDisconnessione(socket);
    },
  );
}

void gestisciMessaggio(Socket socket, String messaggio) {
  print('Ricevuto da ${socket.remoteAddress.address}: $messaggio');
  final parti = messaggio.split('|');
  final comando = parti[0];

  switch (comando) {
    case 'JOIN':
      String nick = parti.length > 1 ? parti[1] : "Sconosciuto";
      gestisciJoin(socket, nick);
      break;
    case 'GIOCA':
      gestisciGioca(socket);
      break;
    case 'POSIZIONI':
      if (parti.length > 1) riceviPosizioni(socket, parti.sublist(1).join('|'));
      break;
    case 'SPARA':
      if (parti.length > 1) spara(socket, int.parse(parti[1]));
      break;
    case 'ESCI':
      gestisciDisconnessione(socket);
      break;
  }
}

void gestisciJoin(Socket socket, String nickname) {
  // Pulisci il socket da ogni stato precedente
  pulisciSocket(socket);

  if (!codaGiocatori.contains(socket)) {
    codaGiocatori.add(socket);
    tempNicknames[socket] = nickname;
    print("Giocatore $nickname aggiunto alla coda. Totale in coda: ${codaGiocatori.length}");
  }

  _inviaMsg(socket, 'ATTESA_GIOCATORE\n');
}

void gestisciGioca(Socket socket) {
  print("Ricevuto GIOCA da ${tempNicknames[socket] ?? 'Unknown'}");

  // Se il socket è già in una partita attiva, ignora
  final partitaEsistente = trovaPartita(socket);
  if (partitaEsistente != null && partitaEsistente.stato != StatoPartita.terminata) {
    print("Socket già in una partita attiva, ignoro GIOCA");
    return;
  }

  // Aggiungi a set di giocatori che vogliono giocare
  if (!inAttesaDiGiocare.contains(socket)) {
    inAttesaDiGiocare.add(socket);
    print("Socket aggiunto a inAttesaDiGiocare. Totale: ${inAttesaDiGiocare.length}");
  }

  // Prova a creare partita se ci sono almeno 2 giocatori pronti
  if (inAttesaDiGiocare.length >= 2) {
    final giocatoriPronti = inAttesaDiGiocare.toList();

    final g1 = giocatoriPronti[0];
    final g2 = giocatoriPronti[1];

    if (!codaGiocatori.contains(g1) || !codaGiocatori.contains(g2)) {
      print("Uno dei giocatori non è più in coda, pulizia necessaria");
      pulisciSocket(g1);
      pulisciSocket(g2);
      return;
    }

    // Rimuovi da tutte le code
    inAttesaDiGiocare.remove(g1);
    inAttesaDiGiocare.remove(g2);
    codaGiocatori.remove(g1);
    codaGiocatori.remove(g2);

    // Crea nuova partita
    final p = Partita(g1, g2);
    p.nick1 = tempNicknames[g1] ?? "G1";
    p.nick2 = tempNicknames[g2] ?? "G2";

    // Rimuovi i nickname temporanei
    tempNicknames.remove(g1);
    tempNicknames.remove(g2);

    partite.add(p);
    print("Partita creata: ${p.nick1} vs ${p.nick2}");

    avviaPosizionamento(p);
  } else {
    _inviaMsg(socket, 'ATTESA_GIOCATORE\n');
    print("In attesa di altro giocatore. Attuali: ${inAttesaDiGiocare.length}");
  }
}

void avviaPosizionamento(Partita partita) {
  partita.stato = StatoPartita.posizionamento;
  _inviaMsg(partita.giocatore1, 'START_POS\n');
  _inviaMsg(partita.giocatore2, 'START_POS\n');
  print("Posizionamento avviato per partita ${partita.nick1} vs ${partita.nick2}");
}

void riceviPosizioni(Socket socket, String json) {
  final partita = trovaPartita(socket);
  if (partita == null) {
    print("ERRORE: Posizioni ricevute ma partita non trovata");
    return;
  }

  try {
    final List<dynamic> dati = jsonDecode(json);
    final navi = dati.map((e) => List<int>.from(e)).toList();

    if (socket == partita.giocatore1) {
      partita.navi1 = navi;
      partita.pos1Pronto = true;
      print("Posizioni ricevute da ${partita.nick1}");
    } else {
      partita.navi2 = navi;
      partita.pos2Pronto = true;
      print("Posizioni ricevute da ${partita.nick2}");
    }

    if (partita.pos1Pronto && partita.pos2Pronto) {
      partita.stato = StatoPartita.inGioco;
      partita.turno = 1; // Giocatore 1 inizia SEMPRE

      print("*** GIOCO AVVIATO: ${partita.nick1} (G1, turno=1) vs ${partita.nick2} (G2, turno=2) ***");
      print("*** Primo turno: ${partita.nick1} ***");

      // Invia messaggi di inizio gioco
      _inviaJson(partita.giocatore1, {
        "tipo": "START_GIOCO",
        "mioTurno": true,  // Giocatore 1 inizia
        "avversario": partita.nick2
      });

      _inviaJson(partita.giocatore2, {
        "tipo": "START_GIOCO",
        "mioTurno": false, // Giocatore 2 aspetta
        "avversario": partita.nick1
      });

      print("Messaggi START_GIOCO inviati");
    }
  } catch (e) {
    print("Errore ricezione posizioni: $e");
  }
}

void spara(Socket socket, int cella) {
  final partita = trovaPartita(socket);
  if (partita == null) {
    print("ERRORE: Spara ma partita non trovata");
    return;
  }

  if (partita.stato != StatoPartita.inGioco) {
    print("ERRORE: Spara ma partita non in gioco (stato: ${partita.stato})");
    return;
  }

  final idx = partita.indice(socket);
  print("Sparo ricevuto da giocatore $idx (turno corrente: ${partita.turno})");

  if (partita.turno != idx) {
    print("ERRORE: Non è il turno di questo giocatore! Turno=${partita.turno}, Player=$idx");
    // Reinvia lo stato corretto
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": false});
    return;
  }

  final colpiEffettuati = idx == 1 ? partita.colpi1 : partita.colpi2;
  if (colpiEffettuati.contains(cella)) {
    print("ERRORE: Cella $cella già colpita");
    return;
  }
  colpiEffettuati.add(cella);

  final naviAvversario = idx == 1 ? partita.navi2 : partita.navi1;
  final socketAvversario = partita.avversario(socket);

  bool colpito = false;
  List<int>? naveColpita;

  for (final nave in naviAvversario) {
    if (nave.contains(cella)) {
      colpito = true;
      naveColpita = nave;
      break;
    }
  }

  print("Risultato sparo cella $cella: ${colpito ? 'COLPITO' : 'ACQUA'}");

  _inviaJson(socket, {"tipo": "RISULTATO", "hit": colpito, "cella": cella});
  _inviaJson(socketAvversario, {"tipo": "SUBITO", "hit": colpito, "cella": cella});

  if (colpito) {
    final affondata = naveColpita!.every((c) => colpiEffettuati.contains(c));
    if (affondata) {
      print("Nave affondata!");
      naviAvversario.remove(naveColpita);
      _inviaJson(socket, {"tipo": "AFFONDATA", "celle": naveColpita});
      _inviaJson(socketAvversario, {"tipo": "PERSA", "celle": naveColpita});

      if (naviAvversario.isEmpty) {
        partita.stato = StatoPartita.terminata;
        _inviaJson(socket, {"tipo": "VITTORIA"});
        _inviaJson(socketAvversario, {"tipo": "SCONFITTA"});
        print("*** PARTITA TERMINATA: Vince ${idx == 1 ? partita.nick1 : partita.nick2} ***");

        Future.delayed(const Duration(seconds: 2), () {
          partite.remove(partita);
          print("Partita rimossa dal server");
        });
        return;
      }
    }
    // Colpito: giocatore mantiene il turno
    print("Colpito! ${idx == 1 ? partita.nick1 : partita.nick2} gioca ancora");
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": true});
    _inviaJson(socketAvversario, {"tipo": "TURNO", "mioTurno": false});
  } else {
    // Acqua: turno passa all'avversario
    partita.turno = idx == 1 ? 2 : 1;
    print("Acqua! Turno passa a ${partita.turno == 1 ? partita.nick1 : partita.nick2}");
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": false});
    _inviaJson(socketAvversario, {"tipo": "TURNO", "mioTurno": true});
  }
}

void gestisciDisconnessione(Socket socket) {
  print("*** Gestione disconnessione per ${socket.remoteAddress.address} ***");

  pulisciSocket(socket);

  final partita = trovaPartita(socket);
  if (partita != null) {
    print("Socket era in una partita, notifico avversario");
    final avv = partita.avversario(socket);
    try {
      _inviaJson(avv, {"tipo": "AVVERSARIO_USCITO"});
    } catch (e) {
      print("Errore notifica avversario: $e");
    }
    partite.remove(partita);
    print("Partita rimossa a causa di disconnessione");
  }

  try {
    socket.close();
  } catch (e) {
    print("Errore chiusura socket: $e");
  }
}

void pulisciSocket(Socket socket) {
  if (codaGiocatori.contains(socket)) {
    codaGiocatori.remove(socket);
    print("Socket rimosso da codaGiocatori");
  }
  if (inAttesaDiGiocare.contains(socket)) {
    inAttesaDiGiocare.remove(socket);
    print("Socket rimosso da inAttesaDiGiocare");
  }
  if (tempNicknames.containsKey(socket)) {
    tempNicknames.remove(socket);
    print("Nickname temporaneo rimosso");
  }
}

Partita? trovaPartita(Socket s) {
  for (final p in partite) {
    if (p.contiene(s)) return p;
  }
  return null;
}

void _inviaJson(Socket s, Map<String, dynamic> data) {
  try {
    final jsonString = jsonEncode(data);
    if (jsonString.isNotEmpty && jsonString != 'null') {
      s.write('$jsonString\n');
      s.flush();
      print("Inviato JSON a ${s.remoteAddress.address}: $jsonString");
    }
  } catch (e) {
    print('Errore invio JSON: $e');
  }
}

void _inviaMsg(Socket s, String msg) {
  try {
    if (msg.trim().isNotEmpty) {
      s.write(msg);
      s.flush();
      print("Inviato MSG a ${s.remoteAddress.address}: ${msg.trim()}");
    }
  } catch (e) {
    print('Errore invio messaggio: $e');
  }
}

// --- BACKGROUND SERVICE ---

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'server_battaglia_channel',
      initialNotificationTitle: 'Battaglia Navale Server',
      initialNotificationContent: 'Inizializzazione...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    fermaServerLogica();
    service.stopSelf();
  });

  try {
    await avviaServerLogica();
  } catch (e) {
    print("ERRORE FATALE AVVIO SERVER: $e");
    service.stopSelf();
    return;
  }

  Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Battaglia Navale Server",
          content: "Attivo - ${partite.length} partite | ${codaGiocatori.length} in coda",
        );
      }
    }

    service.invoke('update', {
      "current_date": DateTime.now().toIso8601String(),
    });
  });
}

// --- UI FLUTTER ---

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String textButton = "Avvia Server";
  bool isRunning = false;
  String ipAddress = "Caricamento...";

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _getIpAddress();
  }

  Future<void> _getIpAddress() async {
    await [Permission.location, Permission.notification].request();

    final info = NetworkInfo();
    var wifiIP = await info.getWifiIP();
    setState(() {
      ipAddress = wifiIP ?? "Non connesso al WiFi";
    });
  }

  void _checkStatus() async {
    final service = FlutterBackgroundService();
    var isRunningNow = await service.isRunning();
    setState(() {
      isRunning = isRunningNow;
      textButton = isRunning ? "Spegni Server" : "Avvia Server";
    });
  }

  void toggleServer() async {
    final service = FlutterBackgroundService();
    var isRunningNow = await service.isRunning();

    if (isRunningNow) {
      service.invoke("stopService");
      setState(() {
        isRunning = false;
        textButton = "Avvia Server";
      });
    } else {
      await service.startService();
      setState(() {
        isRunning = true;
        textButton = "Spegni Server";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Server Battaglia Navale")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Indirizzo IP del Server:",
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Text(
                ipAddress,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text("(Porta: 4040)"),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: toggleServer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: isRunning ? Colors.red : Colors.green,
                ),
                child: Text(
                  textButton,
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Nota: Per connetterti, i dispositivi devono essere connessi allo stesso Wi-Fi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}