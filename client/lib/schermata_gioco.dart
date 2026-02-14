import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'servizio_tcp.dart';

class SchermataGioco extends StatefulWidget {
  final ServizioTCP servizio;
  final List<List<int>> mieNavi;

  const SchermataGioco({
    super.key,
    required this.servizio,
    required this.mieNavi,
  });

  @override
  State<SchermataGioco> createState() => _SchermataGiocoState();
}

class _SchermataGiocoState extends State<SchermataGioco>
    with TickerProviderStateMixin {
  bool mioTurno = false;
  String stato = 'In attesa...';

  Set<int> colpiFatti = {};
  Set<int> colpiSubiti = {};
  Set<int> acquaFatti = {};
  Set<int> acquaSubiti = {};

  Set<int> naviAffondateAvversario = {};
  Set<int> mieNaviAffondate = {};

  late AnimationController _turnoController;
  late Animation<Color?> _turnoColorAnimation;

  Map<int, AnimationController> _explosionControllers = {};

  final TransformationController _transformationControllerDifesa = TransformationController();
  final TransformationController _transformationControllerAttacco = TransformationController();
  double _currentScaleDifesa = 1.0;
  double _currentScaleAttacco = 1.0;

  @override
  void initState() {
    super.initState();
    _aggiornaStatoTestuale();

    _turnoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _turnoColorAnimation = ColorTween(
      begin: Colors.orange.shade100,
      end: Colors.orange.shade300,
    ).animate(_turnoController);

    widget.servizio.onEvento = (msg) {
      if (!mounted) return;
      setState(() {
        switch (msg['tipo']) {
          case 'START_GIOCO':
            mioTurno = msg['mioTurno'] ?? false;
            _aggiornaStatoTestuale();
            if (mioTurno) {
              _turnoController.repeat(reverse: true);
              _mostraPopupTurno();
            } else {
              _turnoController.stop();
            }
            break;
          case 'TURNO':
            bool turnoPrec = mioTurno;
            mioTurno = msg['mioTurno'] ?? false;
            _aggiornaStatoTestuale();

            // Mostra popup solo quando diventa il turno del giocatore
            if (mioTurno && !turnoPrec) {
              _turnoController.repeat(reverse: true);
              _mostraPopupTurno();
            } else if (!mioTurno) {
              _turnoController.stop();
            }
            break;
          case 'RISULTATO':
            final cella = msg['cella'] as int;
            if (msg['hit']) {
              colpiFatti.add(cella);
              _playExplosion(cella);
            } else {
              acquaFatti.add(cella);
            }
            break;
          case 'SUBITO':
            final cella = msg['cella'] as int;
            if (msg['hit']) {
              colpiSubiti.add(cella);
              _playExplosion(cella);
            } else {
              acquaSubiti.add(cella);
            }
            break;
          case 'AFFONDATA':
            naviAffondateAvversario.addAll((msg['celle'] as List).cast<int>());
            break;
          case 'PERSA':
            mieNaviAffondate.addAll((msg['celle'] as List).cast<int>());
            break;
          case 'VITTORIA':
            _mostraPopupFine(
              "VITTORIA",
              "Hai affondato tutta la flotta nemica!",
              Colors.green,
            );
            break;
          case 'SCONFITTA':
            _mostraPopupFine(
              "Sconfitta",
              "La tua flotta è stata distrutta.",
              Colors.red,
            );
            break;
          case 'AVVERSARIO_USCITO':
            _mostraPopupFine(
              "Vittoria",
              "L'avversario ha abbandonato la partita.",
              Colors.orange,
            );
            break;
        }
      });
    };
  }

  @override
  void dispose() {
    _turnoController.dispose();
    _transformationControllerDifesa.dispose();
    _transformationControllerAttacco.dispose();
    for (var controller in _explosionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _playExplosion(int cella) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _explosionControllers[cella] = controller;
    controller.forward().then((_) {
      controller.dispose();
      _explosionControllers.remove(cella);
    });
  }

  void _aggiornaStatoTestuale() {
    stato = mioTurno
        ? "Tocca a te, ${widget.servizio.mioNickname}!"
        : "Turno di ${widget.servizio.nicknameAvversario}...";
  }

  void _mostraPopupTurno() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Turno',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Auto-chiudi dopo 2.5 secondi
        if (animation.status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
        }

        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade700,
                      Colors.orange.shade900,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, value, child) {
                        return Transform.rotate(
                          angle: value * 6.28, // 360 gradi
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flash_on,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const Gap(20),
                    const Text(
                      'IL TUO TURNO!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(12),
                    Text(
                      'Colpisci la flotta di ${widget.servizio.nicknameAvversario}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(20),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'INIZIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getShipAsset(int size, bool isVertical) {
    if (isVertical) {
      return 'assets/images/ship_${size}_vertical.svg';
    }
    return 'assets/images/ship_$size.svg';
  }


  void _mostraPopupFine(String titolo, String msg, Color colorType) {
    final bool isVittoria = colorType == Colors.green;
    final bool isSconfitta = colorType == Colors.red;

    final bgColor = isVittoria
        ? Colors.green.shade50
        : isSconfitta
        ? Colors.red.shade50
        : Colors.orange.shade50;

    final mainColor = isVittoria
        ? Colors.green.shade700
        : isSconfitta
        ? Colors.red.shade700
        : Colors.orange.shade700;

    final textColor = isVittoria
        ? Colors.green.shade900
        : isSconfitta
        ? Colors.red.shade900
        : Colors.orange.shade900;

    final icon = isVittoria
        ? Icons.emoji_events
        : isSconfitta
        ? Icons.sentiment_dissatisfied
        : Icons.star;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: bgColor,
        title: Text(
          titolo,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: mainColor,
            ),
            const Gap(16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              icon: const Icon(Icons.home),
              label: const Text('Torna alla Home'),
            ),
          ),
        ],
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
            const Icon(Icons.warning_amber, color: Colors.red),
            const Gap(12),
            const Text("Abbandonare la battaglia?"),
          ],
        ),
        content: const Text(
          "Se esci ora perderai automaticamente la partita.",
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Continua a giocare"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Abbandona", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (esci == true) {
      widget.servizio.abbandona();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  void spara(int cella) {
    if (!mioTurno || colpiFatti.contains(cella) || acquaFatti.contains(cella)) {
      return;
    }
    widget.servizio.spara(cella);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confermaUscita();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Battaglia in Corso'),
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
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Gap(10),

                AnimatedBuilder(
                  animation: _turnoColorAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: mioTurno
                            ? _turnoColorAnimation.value
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: mioTurno
                              ? Colors.orange.shade700
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mioTurno ? Icons.flash_on : Icons.hourglass_empty,
                            color: mioTurno
                                ? Colors.orange.shade900
                                : Colors.grey.shade700,
                          ),
                          const Gap(12),
                          Text(
                            stato,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: mioTurno
                                  ? Colors.orange.shade900
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Gap(20),

                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield, color: Colors.blue.shade700),
                            const Gap(8),
                            const Text(
                              "LA TUA FLOTTA",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
                        _ZoomableGridContainer(
                          child: _buildGriglia(isDifesa: true),
                        ),
                      ],
                    ),
                  ),
                ),

                const Gap(20),
                Divider(thickness: 2, color: Colors.blue.shade300),
                const Gap(20),

                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gps_fixed, color: Colors.red.shade700),
                            const Gap(8),
                            const Text(
                              "FLOTTA NEMICA",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
                        _ZoomableGridContainer(
                          child: _buildGriglia(isDifesa: false, tap: spara),
                        ),
                      ],
                    ),
                  ),
                ),

                const Gap(20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _confermaUscita,
                    icon: const Icon(Icons.flag),
                    label: const Text(
                      "Abbandona Partita",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const Gap(20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGriglia({required bool isDifesa, Function(int)? tap}) {
    const lettere = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

    // Calcola dimensioni in base allo schermo
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 70;
    final cellSize = (availableWidth / 10).clamp(22.0, 26.0);
    const double spacing = 1.0;
    final double labelSize = cellSize * 0.8;

    // Organizza le navi per dimensione
    Map<int, List<Map<String, dynamic>>> naviPerDimensione = {};
    if (isDifesa) {
      for (var nave in widget.mieNavi) {
        int dim = nave.length;
        naviPerDimensione.putIfAbsent(dim, () => []);

        bool isVert = nave.length > 1 && nave[1] == nave.first + 10;

        naviPerDimensione[dim]!.add({
          'celle': nave,
          'isVertical': isVert,
        });
      }
    }

    // Trova le navi affondate dell'avversario raggruppate
    Map<int, List<Map<String, dynamic>>> naviAffondatePerDimensione = {};
    if (!isDifesa) {
      Set<int> processate = {};
      for (int cella in naviAffondateAvversario) {
        if (processate.contains(cella)) continue;

        List<int> naveCorrente = [cella];
        processate.add(cella);

        int row = cella ~/ 10;
        int col = cella % 10;

        for (int c = col + 1; c < 10; c++) {
          int next = row * 10 + c;
          if (naviAffondateAvversario.contains(next)) {
            naveCorrente.add(next);
            processate.add(next);
          } else {
            break;
          }
        }

        bool isVert = false;
        if (naveCorrente.length == 1) {
          for (int r = row + 1; r < 10; r++) {
            int next = r * 10 + col;
            if (naviAffondateAvversario.contains(next)) {
              naveCorrente.add(next);
              processate.add(next);
              isVert = true;
            } else {
              break;
            }
          }
        }

        int dim = naveCorrente.length;
        naviAffondatePerDimensione.putIfAbsent(dim, () => []);
        naviAffondatePerDimensione[dim]!.add({
          'celle': naveCorrente,
          'isVertical': isVert,
        });
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      fontSize: (cellSize * 0.35).clamp(9, 11),
                    ),
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 2),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          fontSize: (cellSize * 0.3).clamp(8, 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                width: cellSize * 10 + spacing * 9,
                height: cellSize * 10 + spacing * 9,
                child: Stack(
                  children: [
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 100,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                      ),
                      itemBuilder: (_, i) {
                        Color colore = Colors.blue.shade100;

                        if (isDifesa) {
                          if (mieNaviAffondate.contains(i)) {
                            colore = Colors.red.shade400;
                          }
                        } else {
                          if (naviAffondateAvversario.contains(i)) {
                            colore = Colors.green.shade400;
                          }
                        }

                        return GestureDetector(
                          onTap: tap != null && mioTurno ? () => tap(i) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colore,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    if (isDifesa)
                      ...naviPerDimensione.entries.expand((entry) {
                        int dim = entry.key;
                        List<Map<String, dynamic>> naviDim = entry.value;

                        return naviDim.map((naveData) {
                          List<int> nave = naveData['celle'];
                          bool isVert = naveData['isVertical'];

                          int primaCella = nave.first;
                          int row = primaCella ~/ 10;
                          int col = primaCella % 10;

                          bool isAffondata = nave.every((c) => mieNaviAffondate.contains(c));

                          double left = col * (cellSize + spacing);
                          double top = row * (cellSize + spacing);
                          double width = isVert ? cellSize : (cellSize * dim + spacing * (dim - 1));
                          double height = isVert ? (cellSize * dim + spacing * (dim - 1)) : cellSize;

                          return Positioned(
                            left: left,
                            top: top,
                            width: width,
                            height: height,
                            child: Opacity(
                              opacity: isAffondata ? 0.5 : 1.0,
                              child: ColorFiltered(
                                colorFilter: isAffondata
                                    ? const ColorFilter.mode(
                                  Colors.grey,
                                  BlendMode.saturation,
                                )
                                    : const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply,
                                ),
                                child: SvgPicture.asset(
                                  _getShipAsset(dim, isVert),
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          );
                        });
                      }),

                    if (!isDifesa)
                      ...naviAffondatePerDimensione.entries.expand((entry) {
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
                            child: Opacity(
                              opacity: 0.7,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colors.grey,
                                  BlendMode.saturation,
                                ),
                                child: SvgPicture.asset(
                                  _getShipAsset(dim, isVert),
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          );
                        });
                      }),

                    ...List.generate(100, (i) {
                      Widget? overlay;

                      if (isDifesa) {
                        if (colpiSubiti.contains(i)) {
                          overlay = SvgPicture.asset(
                            'assets/images/explosion_ship.svg',
                            width: cellSize,
                            height: cellSize,
                            fit: BoxFit.contain,
                          );
                        } else if (acquaSubiti.contains(i)) {
                          overlay = SvgPicture.asset(
                            'assets/images/explosion_water.svg',
                            width: cellSize,
                            height: cellSize,
                            fit: BoxFit.contain,
                          );
                        }
                      } else {
                        if (colpiFatti.contains(i)) {
                          overlay = SvgPicture.asset(
                            'assets/images/explosion_ship.svg',
                            width: cellSize,
                            height: cellSize,
                            fit: BoxFit.contain,
                          );
                        } else if (acquaFatti.contains(i)) {
                          overlay = SvgPicture.asset(
                            'assets/images/explosion_water.svg',
                            width: cellSize,
                            height: cellSize,
                            fit: BoxFit.contain,
                          );
                        }
                      }

                      if (overlay != null) {
                        int row = i ~/ 10;
                        int col = i % 10;

                        return Positioned(
                          left: col * (cellSize + spacing),
                          top: row * (cellSize + spacing),
                          child: overlay,
                        );
                      }

                      return const SizedBox.shrink();
                    }),
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
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _previousScale = _scale;
        _startOffset = _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(1.0, 3.0);

          if (details.scale != 1.0) {
            // Durante lo zoom
          } else if (_scale > 1.0) {
            // Pan quando già zoomato
            _offset = _startOffset + details.focalPointDelta;
          }
        });
      },
      child: ClipRect(
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          child: Transform(
            transform: Matrix4.identity()
              ..translate(_offset.dx, _offset.dy)
              ..scale(_scale),
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}




