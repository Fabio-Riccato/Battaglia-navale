import 'dart:convert';
import 'dart:io';

class ServizioTCP {
  Socket? socket;
  Function(String)? onMessaggio;

  Future<bool> connetti() async {
    try {
      socket = await Socket.connect('127.0.0.1', 3000);
      socket!.listen((data) {
        String msg = utf8.decode(data).trim();
        if (onMessaggio != null) {
          onMessaggio!(msg);
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  void inviaNavi(List<List<int>> navi) {
    String json = jsonEncode({
      'tipo': 'navi',
      'dati': navi,
    });

    socket?.write('$json\n');
  }

  void spara(int cella) {
    String json = jsonEncode({
      'tipo': 'sparo',
      'dati': cella,
    });

    socket?.write('$json\n');
  }

  void chiudi() {
    socket?.close();
  }
}




