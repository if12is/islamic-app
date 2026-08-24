import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/prayer_calculation_service.dart';
import 'package:islamic_app/features/prayer_times/domain/travel.dart';

void main() {
  group('What shortening actually means', () {
    test('only the four-rak\'ah prayers are halved', () {
      expect(TravelRuling.rakaatTravelling(PrayerIds.dhuhr), 2);
      expect(TravelRuling.rakaatTravelling(PrayerIds.asr), 2);
      expect(TravelRuling.rakaatTravelling(PrayerIds.isha), 2);
    });

    test('Fajr is two either way', () {
      expect(TravelRuling.rakaatAtHome(PrayerIds.fajr), 2);
      expect(TravelRuling.rakaatTravelling(PrayerIds.fajr), 2);
      expect(
        TravelRuling.changeFor(PrayerIds.fajr),
        TravelPrayerChange.unchanged,
      );
    });

    test('Maghrib stays three and is never halved', () {
      // It is the witr of the day. A rule written as "halve everything with
      // more than two" would quietly make it one and a half.
      expect(TravelRuling.rakaatAtHome(PrayerIds.maghrib), 3);
      expect(TravelRuling.rakaatTravelling(PrayerIds.maghrib), 3);
      expect(
        TravelRuling.changeFor(PrayerIds.maghrib),
        TravelPrayerChange.unchanged,
      );
    });

    test('every obligatory prayer has a count, and none is zero', () {
      for (final id in PrayerIds.obligatory) {
        expect(TravelRuling.rakaatAtHome(id), greaterThan(0), reason: id);
        expect(TravelRuling.rakaatTravelling(id), greaterThan(0), reason: id);
      }
    });

    test('sunrise is not a prayer and has no count', () {
      expect(TravelRuling.rakaatAtHome(PrayerIds.sunrise), 0);
    });
  });

  group('Which prayers may be joined', () {
    test('the two pairs are Dhuhr with Asr and Maghrib with Isha', () {
      expect(TravelRuling.joinPartner(PrayerIds.dhuhr), PrayerIds.asr);
      expect(TravelRuling.joinPartner(PrayerIds.asr), PrayerIds.dhuhr);
      expect(TravelRuling.joinPartner(PrayerIds.maghrib), PrayerIds.isha);
      expect(TravelRuling.joinPartner(PrayerIds.isha), PrayerIds.maghrib);
    });

    test('Fajr joins with nothing', () {
      expect(TravelRuling.joinPartner(PrayerIds.fajr), isNull);
    });

    test('Asr and Isha are never joined across the pairs', () {
      // The one mistake a careless pairing makes: Asr and Maghrib are next to
      // each other in the day, and are not a pair.
      expect(TravelRuling.joinPartner(PrayerIds.asr), isNot(PrayerIds.maghrib));
    });

    test('a join brought forward is prayed at the earlier of the pair', () {
      expect(TravelRuling.isFirstOfPair(PrayerIds.dhuhr), isTrue);
      expect(TravelRuling.isFirstOfPair(PrayerIds.asr), isFalse);
      expect(TravelRuling.isFirstOfPair(PrayerIds.maghrib), isTrue);
      expect(TravelRuling.isFirstOfPair(PrayerIds.isha), isFalse);
    });
  });

  group('How far from home', () {
    // Cairo to Alexandria is about 180 km; Cairo to Giza is about 12.
    const cairo = (30.0444, 31.2357);
    const alexandria = (31.2001, 29.9187);
    const giza = (30.0131, 31.2089);

    TravelAssessment at((double, double) place, {double threshold = 83}) =>
        TravelAssessment.from(
          homeLatitude: cairo.$1,
          homeLongitude: cairo.$2,
          currentLatitude: place.$1,
          currentLongitude: place.$2,
          thresholdKm: threshold,
        );

    test('across the city is not travel', () {
      final near = at(giza);
      expect(near.distanceKm, lessThan(20));
      expect(near.beyondThreshold, isFalse);
    });

    test('another governorate is past the threshold', () {
      final far = at(alexandria);
      expect(far.distanceKm, closeTo(180, 15));
      expect(far.beyondThreshold, isTrue);
      expect(far.remainingKm, 0);
    });

    test('the remaining distance counts down and never goes negative', () {
      expect(at(giza).remainingKm, greaterThan(0));
      expect(at(alexandria).remainingKm, 0);
    });

    test('nothing is judged before a home is set', () {
      final none = TravelAssessment.from(
        homeLatitude: null,
        homeLongitude: null,
        currentLatitude: alexandria.$1,
        currentLongitude: alexandria.$2,
      );
      expect(none.hasHome, isFalse);
      // The one thing it must never do: call someone a traveller with nothing
      // to measure from.
      expect(none.beyondThreshold, isFalse);
    });

    test('a threshold the user raised is the one that is used', () {
      expect(at(alexandria, threshold: 120).beyondThreshold, isTrue);
      expect(at(alexandria, threshold: 200).beyondThreshold, isFalse);
    });

    test('an impossible threshold is brought back into range', () {
      expect(TravelDistance.sanitize(0), TravelDistance.minKm);
      expect(TravelDistance.sanitize(10000), TravelDistance.maxKm);
      expect(TravelDistance.sanitize(double.nan), 83);
    });

    test('the offered figures include the two commonly cited ones', () {
      expect(TravelDistance.choices, contains(83.0));
      expect(TravelDistance.choices, contains(88.7));
    });
  });

  group('Noticing a move without nagging about it', () {
    const cairo = (30.0444, 31.2357);
    const alexandria = (31.2001, 29.9187);
    const giza = (30.0131, 31.2089);
    const tanta = (30.7865, 31.0004);

    bool ask(
      (double, double) now, {
      (double, double)? asked,
      (double, double) calculatingFor = cairo,
    }) => CityChangeWatch.shouldAsk(
      calculatingForLatitude: calculatingFor.$1,
      calculatingForLongitude: calculatingFor.$2,
      currentLatitude: now.$1,
      currentLongitude: now.$2,
      lastAskedLatitude: asked?.$1,
      lastAskedLongitude: asked?.$2,
    );

    test('moving across the city raises nothing', () {
      // Prayer times move by a minute or two over this distance. Asking about
      // it would train the user to dismiss the question unread.
      expect(ask(giza), isFalse);
    });

    test('another city raises it once', () {
      expect(ask(alexandria), isTrue);
    });

    test('the same place is not asked about twice', () {
      expect(ask(alexandria, asked: alexandria), isFalse);
    });

    test('a jittery fix in the same place is still the same place', () {
      const drifted = (31.2100, 29.9300);
      expect(ask(drifted, asked: alexandria), isFalse);
    });

    test('carrying on to somewhere else raises it again', () {
      // Tanta is far from both Cairo and Alexandria, so a journey made in
      // stages is not silently swallowed by the first answer.
      expect(ask(tanta, asked: alexandria), isTrue);
    });

    test('nothing is asked when there is nothing to compare against', () {
      expect(
        CityChangeWatch.shouldAsk(
          calculatingForLatitude: null,
          calculatingForLongitude: null,
          currentLatitude: alexandria.$1,
          currentLongitude: alexandria.$2,
        ),
        isFalse,
      );
    });
  });
}
