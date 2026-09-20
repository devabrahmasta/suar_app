class ImpactEstimate {
  final double estimatedMmi;
  final String shakingLevel;

  ImpactEstimate({required this.estimatedMmi, required this.shakingLevel});

  factory ImpactEstimate.fromJson(Map<String, dynamic> json) {
    return ImpactEstimate(
      estimatedMmi: (json['estimatedMmi'] as num).toDouble(),
      shakingLevel: json['shakingLevel'] as String,
    );
  }

  String get shakingLabel {
    switch (shakingLevel) {
      case 'VERY_SEVERE':
        return 'Sangat kuat';
      case 'MODERATE':
        return 'Sedang';
      case 'LIGHT':
        return 'Ringan';
      default:
        return 'Lemah';
    }
  }
}
