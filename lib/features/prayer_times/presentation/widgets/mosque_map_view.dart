import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../domain/mosque_map.dart';

/// An embedded Google map of the mosques around the user.
///
/// It sits beside the list rather than replacing it. The list knows how far
/// each mosque is and which way, and it can hand one to a maps app; the map
/// knows about mosques the list has never heard of. Neither is a substitute
/// for the other, so the screen carries both.
class MosqueMapView extends StatefulWidget {
  const MosqueMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.radiusMetres,
    required this.language,
  });

  final double latitude;
  final double longitude;
  final int radiusMetres;

  /// Passed in rather than read from the tree: the controller is built in
  /// `initState`, where inherited widgets are not yet safe to look up.
  final String language;

  /// Whether this build can show a map at all.
  ///
  /// Two separate reasons it might not: no key was supplied at build time, or
  /// this is the web build, where there is no WebView to put one in.
  static bool get isAvailable => MosqueMap.isConfigured && !kIsWeb;

  static const double height = 280;

  @override
  State<MosqueMapView> createState() => _MosqueMapViewState();
}

class _MosqueMapViewState extends State<MosqueMapView> {
  WebViewController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(MosqueMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing the radius changes the zoom, so the map has to be told.
    if (oldWidget.radiusMetres != widget.radiusMetres ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.language != widget.language) {
      _build();
    }
  }

  void _build() {
    if (!MosqueMapView.isAvailable) {
      return;
    }

    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          // So the card's own surface shows through until Google's tiles
          // arrive, rather than a white flash in the dark theme.
          ..setBackgroundColor(Colors.transparent)
          ..setNavigationDelegate(
            NavigationDelegate(
              onWebResourceError: (error) {
                // Only the top frame failing is worth reporting; a missing
                // tile inside Google's own frame is not this widget's problem.
                if (error.isForMainFrame ?? true) {
                  if (mounted) {
                    setState(() => _failed = true);
                  }
                }
              },
            ),
          );

    controller.loadHtmlString(
      MosqueMap.html(
        latitude: widget.latitude,
        longitude: widget.longitude,
        radiusMetres: widget.radiusMetres,
        term: widget.language == 'ar' ? 'مسجد' : 'mosque',
        language: widget.language,
      ),
      // A base URL, so the frame is loaded by a page with an origin rather
      // than by `about:blank`, which Google's embed refuses.
      baseUrl: 'https://www.google.com/',
    );

    setState(() {
      _controller = controller;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!MosqueMapView.isAvailable) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final controller = _controller;

    if (_failed || controller == null) {
      return AppCard(
        child: Text(
          context.tr('mosques_map_failed'),
          style: AppTextStyles.caption(context),
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppRadii.mdAll,
      child: SizedBox(
        height: MosqueMapView.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line),
            borderRadius: AppRadii.mdAll,
          ),
          child: WebViewWidget(controller: controller),
        ),
      ),
    );
  }
}
