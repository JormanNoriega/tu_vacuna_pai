/// Resultado del clonado del catalogo global hacia una institucion.
class CloneCatalogResult {
  const CloneCatalogResult({
    required this.vaccinesEnabled,
    required this.optionsCopied,
    required this.vaccinesTotal,
  });

  factory CloneCatalogResult.fromJson(Map<String, dynamic> json) {
    return CloneCatalogResult(
      vaccinesEnabled: json['vaccinesEnabled'] as int,
      optionsCopied: json['optionsCopied'] as int,
      vaccinesTotal: json['vaccinesTotal'] as int,
    );
  }

  final int vaccinesEnabled;
  final int optionsCopied;
  final int vaccinesTotal;
}
