/// Live radio and television, from mp3quran.net plus what it leaves out.
library;

/// What kind of stream this is.
enum BroadcastKind {
  /// Audio only. Plays in the background like a recitation does.
  radio,

  /// HLS video. Needs the screen, so it stops when the page closes.
  tv,
}

/// One station or channel.
class Broadcast {
  const Broadcast({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    this.fallbackUrl,
    this.pinned = false,
    this.noteAr = '',
  });

  final String id;
  final String name;

  /// Where to play from.
  final String url;

  /// Where to try when [url] will not answer.
  ///
  /// The catalogue publishes `backup.qurango.net`, which fails on roughly one
  /// station in five while the primary host answers every time. So the primary
  /// is tried first and the address the catalogue gave is kept as the fallback
  /// — the reverse of what the field names suggest, and the right way round.
  final String? fallbackUrl;

  final BroadcastKind kind;

  /// Kept at the top of the list.
  final bool pinned;

  /// Shown under the name where there is something worth saying.
  final String noteAr;

  /// Every address to try, in order.
  List<String> get sources => [url, if (fallbackUrl != null) fallbackUrl!];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'fallback': fallbackUrl,
    'kind': kind.name,
    'pinned': pinned,
    'note': noteAr,
  };

  static Broadcast? fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    final id = json['id']?.toString();
    if (url == null || url.isEmpty || id == null || id.isEmpty) {
      return null;
    }
    return Broadcast(
      id: id,
      name: (json['name'] as String? ?? '').trim(),
      url: url,
      fallbackUrl: json['fallback'] as String?,
      kind:
          json['kind'] == BroadcastKind.tv.name
              ? BroadcastKind.tv
              : BroadcastKind.radio,
      pinned: json['pinned'] == true,
      noteAr: json['note'] as String? ?? '',
    );
  }
}
