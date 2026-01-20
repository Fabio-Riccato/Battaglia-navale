class Nave {
  final int dimensione;
  List<int> celle;
  bool affondata = false;

  Nave(this.dimensione, this.celle);

  bool controllaAffondata(Set<int> colpiSubiti) {
    affondata = celle.every(colpiSubiti.contains);
    return affondata;
  }
}

