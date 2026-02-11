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

  for (var s in codaGiocatori) { s.close(); }
  codaGiocatori.clear();

  for (var s in inAttesaDiGiocare) { s.close(); }
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
  bool g1Confermato = false;
  bool g2Confermato = false;
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
    onDone: () => gestisciDisconnessione(socket),
    onError: (_) => gestisciDisconnessione(socket),
  );
}

void gestisciMessaggio(Socket socket, String messaggio) {
  print('Ricevuto: $messaggio');
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
  if (!codaGiocatori.contains(socket)) {
    codaGiocatori.add(socket);
    tempNicknames[socket] = nickname;
    print("Giocatore $nickname aggiunto alla coda.");
  }

  if (codaGiocatori.length >= 2) {
    final g1 = codaGiocatori.removeAt(0);
    final g2 = codaGiocatori.removeAt(0);
    final p = Partita(g1, g2);
    p.nick1 = tempNicknames[g1] ?? "G1";
    p.nick2 = tempNicknames[g2] ?? "G2";
    tempNicknames.remove(g1);
    tempNicknames.remove(g2);

    if (inAttesaDiGiocare.contains(g1)) {
      p.g1Confermato = true;
      inAttesaDiGiocare.remove(g1);
    }
    if (inAttesaDiGiocare.contains(g2)) {
      p.g2Confermato = true;
      inAttesaDiGiocare.remove(g2);
    }

    partite.add(p);
    print("Partita creata: ${p.nick1} vs ${p.nick2}");

    if (p.g1Confermato && p.g2Confermato) {
      avviaPosizionamento(p);
    } else {
      g1.write('ATTESA_GIOCATORE\n');
      g2.write('ATTESA_GIOCATORE\n');
    }
  } else {
    socket.write('ATTESA_GIOCATORE\n');
  }
}

void gestisciGioca(Socket socket) {
  final partita = trovaPartita(socket);

  if (partita == null) {
    if (codaGiocatori.contains(socket)) {
      inAttesaDiGiocare.add(socket);
      print("Giocatore in coda ha premuto GIOCA. In attesa di avversario.");
    }
    socket.write('ATTESA_GIOCATORE\n');
    return;
  }

  if (socket == partita.giocatore1) partita.g1Confermato = true;
  else partita.g2Confermato = true;

  if (partita.g1Confermato && partita.g2Confermato) {
    avviaPosizionamento(partita);
  } else {
    socket.write('ATTESA_GIOCATORE\n');
  }
}

void avviaPosizionamento(Partita partita) {
  partita.stato = StatoPartita.posizionamento;
  partita.giocatore1.write('START_POS\n');
  partita.giocatore2.write('START_POS\n');
}

void riceviPosizioni(Socket socket, String json) {
  final partita = trovaPartita(socket);
  if (partita == null) return;

  try {
    final List<dynamic> dati = jsonDecode(json);
    final navi = dati.map((e) => List<int>.from(e)).toList();

    if (socket == partita.giocatore1) {
      partita.navi1 = navi;
      partita.pos1Pronto = true;
    } else {
      partita.navi2 = navi;
      partita.pos2Pronto = true;
    }

    if (partita.pos1Pronto && partita.pos2Pronto) {
      partita.stato = StatoPartita.inGioco;
      partita.turno = 1;

      _inviaJson(partita.giocatore1, {
        "tipo": "START_GIOCO",
        "mioTurno": true,
        "avversario": partita.nick2
      });
      _inviaJson(partita.giocatore2, {
        "tipo": "START_GIOCO",
        "mioTurno": false,
        "avversario": partita.nick1
      });
    }
  } catch (e) {
    print("Errore ricezione posizioni: $e");
  }
}

void spara(Socket socket, int cella) {
  final partita = trovaPartita(socket);
  if (partita == null || partita.stato != StatoPartita.inGioco) return;

  final idx = partita.indice(socket);
  if (partita.turno != idx) return;

  final colpiEffettuati = idx == 1 ? partita.colpi1 : partita.colpi2;
  if (colpiEffettuati.contains(cella)) return;
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

  _inviaJson(socket, {"tipo": "RISULTATO", "hit": colpito, "cella": cella});
  _inviaJson(socketAvversario, {"tipo": "SUBITO", "hit": colpito, "cella": cella});

  if (colpito) {
    final affondata = naveColpita!.every((c) => colpiEffettuati.contains(c));
    if (affondata) {
      naviAvversario.remove(naveColpita);
      _inviaJson(socket, {"tipo": "AFFONDATA", "celle": naveColpita});
      _inviaJson(socketAvversario, {"tipo": "PERSA", "celle": naveColpita});

      if (naviAvversario.isEmpty) {
        partita.stato = StatoPartita.terminata;
        _inviaJson(socket, {"tipo": "VITTORIA"});
        _inviaJson(socketAvversario, {"tipo": "SCONFITTA"});
        return;
      }
    }
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": true});
    _inviaJson(socketAvversario, {"tipo": "TURNO", "mioTurno": false});
  } else {
    partita.turno = idx == 1 ? 2 : 1;
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": false});
    _inviaJson(socketAvversario, {"tipo": "TURNO", "mioTurno": true});
  }
}

void gestisciDisconnessione(Socket socket) {
  if (codaGiocatori.contains(socket)) codaGiocatori.remove(socket);
  if (inAttesaDiGiocare.contains(socket)) inAttesaDiGiocare.remove(socket);
  tempNicknames.remove(socket);

  final partita = trovaPartita(socket);
  if (partita != null) {
    final avv = partita.avversario(socket);
    try {
      _inviaJson(avv, {"tipo": "AVVERSARIO_USCITO"});
    } catch (_) {}
    partite.remove(partita);
  }
  try { socket.close(); } catch (_) {}
}

Partita? trovaPartita(Socket s) {
  for (final p in partite) {
    if (p.contiene(s)) return p;
  }
  return null;
}

void _inviaJson(Socket s, Map<String, dynamic> data) {
  try {
    s.write('${jsonEncode(data)}\n');
  } catch (_) {}
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

  // ✅ TIMER CORRETTO - UNA SOLA VOLTA
  Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Battaglia Navale Server",
          content: "Attivo - ${partite.length} partite in corso",
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
