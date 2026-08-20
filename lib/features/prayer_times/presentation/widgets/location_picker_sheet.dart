import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/providers/app_providers.dart';

/// Choose where the app thinks you are: follow the device, or pin a city.
///
/// Pinning matters for people who keep location off, and for anyone who wants
/// their home city's times while travelling.
class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const LocationPickerSheet(),
    );
  }

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final languageCode = ref.read(localeProvider).languageCode;
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await LocationService.search(
        value,
        languageCode: languageCode,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    });
  }

  Future<void> _useAutomatic() async {
    await applyLocationChoice(ref);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pick(PlaceSuggestion place) async {
    await applyLocationChoice(ref, place: place);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManual = ref.watch(locationIsManualProvider);
    final label = ref.watch(locationLabelProvider).value ?? '';

    return Directionality(
      textDirection: context.appTextDirection,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('location_settings'),
              style: AppTextStyles.display(context, fontSize: 19),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('location_settings_desc'),
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(context.tr('location_automatic')),
              subtitle: Text(
                isManual
                    ? context.tr('location_automatic_desc')
                    : (label.isEmpty ? context.tr('location') : label),
              ),
              trailing:
                  isManual
                      ? null
                      : Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              onTap: _useAutomatic,
            ),
            const Divider(height: 24),
            TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: context.tr('location_search'),
                hintText: context.tr('location_search_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (_results.isEmpty && _controller.text.trim().length >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.tr('location_no_results'),
                  style: AppTextStyles.caption(context),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final place in _results)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(place.label),
                        subtitle: Text(
                          '${place.latitude.toStringAsFixed(3)}, '
                          '${place.longitude.toStringAsFixed(3)}',
                          style: AppTextStyles.caption(context),
                        ),
                        onTap: () => _pick(place),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
