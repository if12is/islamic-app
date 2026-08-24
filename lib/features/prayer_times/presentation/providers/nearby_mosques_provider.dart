import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../data/services/mosque_finder.dart';
import '../../domain/nearby_mosque.dart';

/// What the nearest-mosques screen is showing right now.
class NearbyMosquesState {
  const NearbyMosquesState({
    this.result,
    this.radiusMetres = MosqueSearch.defaultRadius,
    this.loading = false,
    this.failure,
  });

  final MosqueSearchResult? result;
  final int radiusMetres;
  final bool loading;

  /// Set only when a search was attempted and could not be completed.
  ///
  /// Kept apart from an empty result on purpose: a desert really does have no
  /// mosque within ten kilometres, and a server that did not answer has told
  /// us nothing at all. Collapsing the two into one empty list is how an app
  /// ends up stating, with confidence, something it never learned.
  final MosqueLookupFailure? failure;

  List<NearbyMosque> get mosques => result?.mosques ?? const [];

  /// A search ran, reached the server, and there was genuinely nothing there.
  bool get searchedAndEmpty =>
      !loading && failure == null && result != null && mosques.isEmpty;

  NearbyMosquesState copyWith({
    MosqueSearchResult? result,
    int? radiusMetres,
    bool? loading,
    MosqueLookupFailure? failure,
    bool clearFailure = false,
    bool clearResult = false,
  }) {
    return NearbyMosquesState(
      result: clearResult ? null : (result ?? this.result),
      radiusMetres: radiusMetres ?? this.radiusMetres,
      loading: loading ?? this.loading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class NearbyMosquesController extends Notifier<NearbyMosquesState> {
  @override
  NearbyMosquesState build() => const NearbyMosquesState();

  /// Load the list, preferring what is already on disk.
  ///
  /// The cache is checked first rather than as a fallback because opening this
  /// screen twice in a row should not cost two queries against a server that
  /// allows two at a time.
  Future<void> load({bool refresh = false}) async {
    if (state.loading) {
      return;
    }
    state = state.copyWith(loading: true, clearFailure: true);

    try {
      final coordinates = await ref.read(
        currentLocationCoordinatesProvider.future,
      );

      if (!refresh) {
        final cached = await MosqueFinder.cached(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
          radiusMetres: state.radiusMetres,
        );
        if (cached != null) {
          state = state.copyWith(result: cached, loading: false);
          return;
        }
      }

      final result = await MosqueFinder.search(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        radiusMetres: state.radiusMetres,
      );
      state = state.copyWith(result: result, loading: false);
    } on MosqueLookupException catch (e) {
      state = state.copyWith(loading: false, failure: e.reason);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        failure: MosqueLookupFailure.offline,
      );
    }
  }

  Future<void> setRadius(int metres) async {
    if (metres == state.radiusMetres) {
      return;
    }
    state = state.copyWith(radiusMetres: metres, clearResult: true);
    await load();
  }
}

final nearbyMosquesProvider =
    NotifierProvider<NearbyMosquesController, NearbyMosquesState>(
      NearbyMosquesController.new,
    );
