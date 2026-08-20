import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import 'seasonal_decor.dart';

/// The wash every page sits on.
///
/// Two soft pools of colour — the accent at the top, the identity green at the
/// bottom — over the flat ground. It is what stops a light interface from
/// reading as a blank sheet, and it is where a season shows up first: change
/// the two mesh tokens and every screen changes with them.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.ground),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -1.05),
                  radius: 1.25,
                  colors: [tokens.meshTop, tokens.ground.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.95, 1.1),
                  radius: 1.15,
                  colors: [
                    tokens.meshBottom,
                    tokens.ground.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // The season's moving decoration sits between the wash and the
          // content, so it dresses every screen without any screen asking.
          Positioned.fill(
            child: SeasonalDecor(
              event: SeasonalDecorScope.of(context),
              child: const SizedBox.expand(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// The scaffold every screen uses.
///
/// It carries three things no screen should have to remember: the wash, the
/// right text direction, and the clearance the floating glass bar needs to
/// have something scrolling underneath it. Glass with a flat colour behind it
/// is not glass — it is a grey rectangle.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBack = false,
    this.onBack,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomBar,
    this.extendBody = true,
  });

  final Widget body;

  /// Localization key for the app-bar title.
  final String? title;

  /// Used instead of [title] when the header is not a plain string.
  final Widget? titleWidget;

  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomBar;
  final bool extendBody;

  /// Padding for a scrollable that must clear the floating nav bar.
  static const EdgeInsets scrollPadding = EdgeInsets.fromLTRB(
    AppSpacing.page,
    AppSpacing.sm,
    AppSpacing.page,
    AppSpacing.navClearance,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasHeader =
        title != null || titleWidget != null || showBack || actions != null;

    return Directionality(
      textDirection: context.appTextDirection,
      child: MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: extendBody,
          // Behind the bar only when there is no bar: with a header, extending
          // pushes the first row of content underneath the title and the two
          // read as one stuck-together block.
          extendBodyBehindAppBar: !hasHeader,
          appBar:
              hasHeader
                  ? AppBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    centerTitle: true,
                    automaticallyImplyLeading: false,
                    leading: leading ?? (showBack ? _BackButton(onBack) : null),
                    title:
                        titleWidget ??
                        (title == null
                            ? null
                            : Text(
                              context.tr(title!),
                              style: AppTextStyles.display(
                                context,
                                fontSize: 18,
                                color: tokens.ink,
                              ),
                            )),
                    actions: actions,
                  )
                  : null,
          body: SafeArea(bottom: false, child: body),
          bottomNavigationBar: bottomBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton(this.onBack);

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Material(
        color: tokens.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              context.isAppRtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              size: 19,
              color: tokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
