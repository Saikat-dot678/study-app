class StudyProgress {
  const StudyProgress({
    required this.path,
    required this.lastOpened,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.page = 0,
    this.pageCount = 0,
  });

  final String path;
  final DateTime lastOpened;
  final Duration position;
  final Duration duration;
  final int page;
  final int pageCount;

  double get fraction {
    if (pageCount > 0) return (page / pageCount).clamp(0, 1);
    if (duration.inMilliseconds > 0) {
      return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
    }
    return 0;
  }

  bool get hasProgress => page > 0 || position > Duration.zero;

  StudyProgress copyWith({
    DateTime? lastOpened,
    Duration? position,
    Duration? duration,
    int? page,
    int? pageCount,
  }) {
    return StudyProgress(
      path: path,
      lastOpened: lastOpened ?? this.lastOpened,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      page: page ?? this.page,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  factory StudyProgress.fromJson(String path, Map<String, dynamic> json) {
    return StudyProgress(
      path: path,
      lastOpened: DateTime.fromMillisecondsSinceEpoch(
        (json['lastOpened'] as num?)?.toInt() ?? 0,
      ),
      position: Duration(
        milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0,
      ),
      duration: Duration(
        milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
      ),
      page: (json['page'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'lastOpened': lastOpened.millisecondsSinceEpoch,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'page': page,
    'pageCount': pageCount,
  };
}

class StudyMetadata {
  const StudyMetadata({
    this.favorites = const {},
    this.pins = const {},
    this.progress = const {},
    this.recentDestinations = const [],
  });

  final Set<String> favorites;
  final Set<String> pins;
  final Map<String, StudyProgress> progress;
  final List<String> recentDestinations;

  factory StudyMetadata.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'] as Map? ?? const {};
    return StudyMetadata(
      favorites: (json['favorites'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      pins: (json['pins'] as List? ?? const []).whereType<String>().toSet(),
      progress: rawProgress.map(
        (key, value) => MapEntry(
          key.toString(),
          StudyProgress.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      recentDestinations: (json['recentDestinations'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'favorites': favorites.toList()..sort(),
    'pins': pins.toList()..sort(),
    'progress': progress.map((path, value) => MapEntry(path, value.toJson())),
    'recentDestinations': recentDestinations,
  };
}
