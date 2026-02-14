import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'servizio_tcp.dart';
import 'schermata_gioco.dart';

class SchermataPosizionamento extends StatefulWidget {
  final ServizioTCP servizio;
  const SchermataPosizionamento({super.key, required this.servizio});

  @override
  State<SchermataPosizionamento> createState() =>
      _SchermataPosizionamentoState();
}

class _SchermataPosizionamentoState extends State<SchermataPosizionamento>
    with SingleTickerProviderStateMixin {
  final flotta = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
  int indice = 0;
  bool verticale = false;

  List<List<int>> navi = [];
  List<int> anteprima = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getShipAsset(int size, bool isVertical) {
    if (isVertical) {
      return 'assets/images/ship_${size}_vertical.svg';
    }
    return 'assets/images/ship_$size.svg';
  }

  void seleziona(int cella) {
    if (indice >= flotta.length) return;
    int r = cella ~/ 10;
    int c = cella % 10;
    final size = flotta[indice];

    if (verticale) {
      if (r + size > 10) r = 10 - size;
    } else {
      if (c + size > 10) c = 10 - size;
    }

    List<int> nuova = [];
    for (int i = 0; i < size; i++) {
      int nr = r + (verticale ? i : 0);
      int nc = c + (verticale ? 0 : i);
      nuova.add(nr * 10 + nc);
    }

    if (navi.expand((e) => e).any((pos) => nuova.contains(pos))) return;
    setState(() => anteprima = nuova);
  }

  void confermaNave() {
    if (anteprima.isEmpty) return;
    setState(() {
      navi.add(List.from(anteprima));
      anteprima.clear();
      indice++;
    });
  }

  void confermaTutto() {
    widget.servizio.inviaNavi(navi);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SchermataGioco(
          servizio: widget.servizio,
          mieNavi: navi,
        ),
      ),
    );
  }

  Future<void> _confermaUscita() async {
    final esci = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const Gap(12),
            const Text("Uscire dal posizionamento?"),
          ],
        ),
        content: const Text(
          "Se esci ora perderai la connessione alla partita.",
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Esci", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (esci == true) {
      widget.servizio.abbandona();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finito = indice >= flotta.length;
    final naviRimanenti = flotta.length - indice;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confermaUscita();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Posiziona la Flotta'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confermaUscita,
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100,
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Gap(10),

                Card(
                  elevation: 4,
                  color: finito ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (!finito) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_boat,
                                color: Colors.blue.shade700,
                                size: 32,
                              ),
                              const Gap(12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nave da ${flotta[indice]} caselle',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Navi rimanenti: $naviRimanenti',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 32,
                              ),
                              const Gap(12),
                              const Text(
                                'Flotta Pronta!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            'Tutte le navi sono state posizionate',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Gap(20),

                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ZoomableGridContainer(
                      child: _buildGriglia(),
                    ),
                  ),
                ),
                const Gap(20),

                if (!finito) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verticale
                                ? Colors.blue.shade700
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: Icon(verticale
                              ? Icons.swap_vert
                              : Icons.swap_horiz),
                          label: Text(
                            verticale ? 'Verticale' : 'Orizzontale',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => setState(() {
                            verticale = !verticale;
                            anteprima.clear();
                          }),
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: anteprima.isEmpty
                                ? Colors.grey.shade400
                                : Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text(
                            'Conferma',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: anteprima.isEmpty ? null : confermaNave,
                        ),
                      ),
                    ],
                  ),
                ],

                if (finito) ...[
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          elevation: 8,
                        ),
                        icon: const Icon(Icons.play_arrow, size: 28),
                        label: const Text(
                          'AVVIA BATTAGLIA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: confermaTutto,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGriglia() {
    const lettere = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

    // Calcola dimensioni in base allo schermo
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 80; // Margini e padding
    final cellSize = (availableWidth / 10).clamp(24.0, 30.0);
    const double spacing = 2.0;
    final double labelSize = cellSize * 0.85;

    // Organizza navi per dimensione
    Map<int, List<Map<String, dynamic>>> naviPerDimensione = {};
    for (var nave in navi) {
      int dim = nave.length;
      naviPerDimensione.putIfAbsent(dim, () => []);

      bool isVert = nave.length > 1 && nave[1] == nave.first + 10;

      naviPerDimensione[dim]!.add({
        'celle': nave,
        'isVertical': isVert,
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con lettere
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: labelSize),
              ...lettere.map((l) => SizedBox(
                width: cellSize,
                child: Center(
                  child: Text(
                    l,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: (cellSize * 0.4).clamp(10, 13),
                    ),
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 4),

          // Griglia con numeri laterali
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Numeri laterali
              Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  10,
                      (i) => SizedBox(
                    height: cellSize,
                    width: labelSize,
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: (cellSize * 0.35).clamp(9, 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Griglia celle
              SizedBox(
                width: cellSize * 10 + spacing * 9,
                height: cellSize * 10 + spacing * 9,
                child: Stack(
                  children: [
                    // Griglia base
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 100,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                      ),
                      itemBuilder: (_, i) {
                        final isAnteprima = anteprima.contains(i);

                        return GestureDetector(
                          onTap: () => seleziona(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isAnteprima
                                  ? Colors.orange.shade400
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: isAnteprima
                                    ? Colors.orange.shade700
                                    : Colors.blue.shade300,
                                width: isAnteprima ? 2 : 1,
                              ),
                              boxShadow: isAnteprima
                                  ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),

                    // Layer navi confermate
                    ...naviPerDimensione.entries.expand((entry) {
                      int dim = entry.key;
                      List<Map<String, dynamic>> naviDim = entry.value;

                      return naviDim.map((naveData) {
                        List<int> nave = naveData['celle'];
                        bool isVert = naveData['isVertical'];

                        int primaCella = nave.first;
                        int row = primaCella ~/ 10;
                        int col = primaCella % 10;

                        double left = col * (cellSize + spacing);
                        double top = row * (cellSize + spacing);
                        double width = isVert ? cellSize : (cellSize * dim + spacing * (dim - 1));
                        double height = isVert ? (cellSize * dim + spacing * (dim - 1)) : cellSize;

                        return Positioned(
                          left: left,
                          top: top,
                          width: width,
                          height: height,
                          child: SvgPicture.asset(
                            _getShipAsset(dim, isVert),
                            fit: BoxFit.fill,
                          ),
                        );
                      });
                    }),

                    // Anteprima nave
                    if (anteprima.isNotEmpty) ...[
                          () {
                        int primaCella = anteprima.first;
                        int row = primaCella ~/ 10;
                        int col = primaCella % 10;
                        int dim = anteprima.length;

                        double left = col * (cellSize + spacing);
                        double top = row * (cellSize + spacing);
                        double width = verticale ? cellSize : (cellSize * dim + spacing * (dim - 1));
                        double height = verticale ? (cellSize * dim + spacing * (dim - 1)) : cellSize;

                        return Positioned(
                          left: left,
                          top: top,
                          width: width,
                          height: height,
                          child: Opacity(
                            opacity: 0.7,
                            child: SvgPicture.asset(
                              _getShipAsset(dim, verticale),
                              fit: BoxFit.fill,
                            ),
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoomableGridContainer extends StatefulWidget {
  final Widget child;

  const _ZoomableGridContainer({required this.child});

  @override
  State<_ZoomableGridContainer> createState() => _ZoomableGridContainerState();
}

class _ZoomableGridContainerState extends State<_ZoomableGridContainer> {
  double _scale = 1.0;
  double _previousScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _previousScale = _scale;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(1.0, 3.0);
        });
      },
      child: Center(
        child: Transform.scale(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}