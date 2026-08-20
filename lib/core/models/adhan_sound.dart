/// An adhan the user can pick for prayer alerts.
///
/// Bundled sounds ship as Android raw resources; a custom one is a
/// `content://` URI the user imported or picked from the device, which the
/// system can read and therefore play.
class AdhanSound {
  const AdhanSound({
    required this.id,
    required this.rawResource,
    required this.nameKey,
    this.credit,
  });

  final String id;

  /// File name (without extension) in `android/app/src/main/res/raw/`.
  final String? rawResource;

  /// Localization key for the display name.
  final String nameKey;

  /// Reciter/source line shown under the name, when there is one.
  final String? credit;
}

/// Which adhan a prayer should play.
class AdhanSoundSelection {
  const AdhanSoundSelection({required this.id, this.uri, this.title});

  /// A bundled sound id, [systemId], or [customId].
  final String id;

  /// `content://` URI, set only for [customId].
  final String? uri;

  /// Display name for a custom sound.
  final String? title;

  static const String systemId = 'system';
  static const String customId = 'custom';

  static const AdhanSoundSelection system = AdhanSoundSelection(id: systemId);

  bool get isCustom => id == customId && (uri?.isNotEmpty ?? false);

  /// A custom selection without a usable URI is treated as the default sound.
  AdhanSoundSelection get sanitized =>
      id == customId && !isCustom ? system : this;

  AdhanSoundSelection copyWith({String? id, String? uri, String? title}) {
    return AdhanSoundSelection(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (uri != null) 'uri': uri,
    if (title != null) 'title': title,
  };

  factory AdhanSoundSelection.fromJson(Map<dynamic, dynamic> json) {
    final id = json['id'];
    return AdhanSoundSelection(
      id: id is String && id.isNotEmpty ? id : systemId,
      uri: json['uri'] is String ? json['uri'] as String : null,
      title: json['title'] is String ? json['title'] as String : null,
    ).sanitized;
  }

  @override
  bool operator ==(Object other) =>
      other is AdhanSoundSelection &&
      other.id == id &&
      other.uri == uri &&
      other.title == title;

  @override
  int get hashCode => Object.hash(id, uri, title);
}
