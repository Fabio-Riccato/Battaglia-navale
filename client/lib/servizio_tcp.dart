import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ServizioTCP {
  Socket? socket;

  // Dati giocatore
  String mioNickname = "";
  String nicknameAvversario = "Avversario";

  final StreamController<String> _controller = StreamController.broadcast();
  Function(Map<String, dynamic>)? onEvento;

  Future<bool> connetti(String ip, String nickname, [int porta = 4040]) async {
    mioNickname = nickname;
    try {
      // Timeout di 5 secondi per evitare blocchi infiniti
      socket = await Socket.connect(ip, porta).timeout(const Duration(seconds: 5));

      socket!.listen(
            (data) {
          final messaggioCompleto = utf8.decode(data);
          for (final line in messaggioCompleto.split('\n')) {
            if (line.trim().isEmpty) continue;
            _gestisciMessaggio(line.trim());
          }
        },
        onError: (e) {
          print("Errore socket: $e");
          _controller.add("ERRORE");
        },
        onDone: () {
          _controller.add("DISCONNESSO");
        },
      );

      socket!.write('JOIN|$nickname\n');
      return true;
    } catch (e) {
      print("Impossibile connettere: $e");
      return false;
    }
  }

  void _gestisciMessaggio(String msg) {
    _controller.add(msg);

    try {
      if (msg.startsWith('{') || msg.startsWith('[')) {
        final json = jsonDecode(msg);

        if (json['tipo'] == 'START_GIOCO' && json.containsKey('avversario')) {
          nicknameAvversario = json['avversario'];
        }

        if (onEvento != null && json is Map<String, dynamic>) {
          onEvento!(json);
        }
      }
    } catch (_) {}
  }

  void gioca() {
    socket?.write('GIOCA\n');
  }

  void inviaNavi(List<List<int>> posizioni) {
    final jsonString = jsonEncode(posizioni);
    socket?.write('POSIZIONI|$jsonString\n');
  }

  void spara(int cella) {
    socket?.write('SPARA|$cella\n');
  }

  void abbandona() {
    // Invia il comando e distrugge il socket
    try {
      socket?.write('ESCI\n');
      socket?.destroy();
    } catch (e) {
      print("Errore durante abbandono: $e");
    }
  }

  Future<bool> attendiStart() async {
    await for (final msg in _controller.stream) {
      if (msg.contains('START_POS')) return true;
      if (msg.contains('ATTESA_GIOCATORE')) continue;
    }
    return false;
  }
}







