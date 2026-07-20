class LyricLine {
  final int timeMs;
  final String text;

  const LyricLine({required this.timeMs, required this.text});

  factory LyricLine.fromMap(Map<String, dynamic> map) => LyricLine(
        timeMs: (map['timeMs'] as num).toInt(),
        text: map['text'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'timeMs': timeMs, 'text': text};
}
