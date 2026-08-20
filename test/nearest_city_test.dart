import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/nearest_city_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => NearestCityService.ensureLoaded());

  group('Naming a point', () {
    test('a street in Damanhur is Damanhur, Beheira, Egypt', () {
      final city = NearestCityService.nearest(31.0341, 30.4682);

      expect(city, isNotNull);
      expect(city!.label('ar'), 'دمنهور، البحيرة، مصر');
    });

    test('names carry their definite article', () {
      final city = NearestCityService.nearest(31.0409, 31.3785);

      expect(city!.nameAr, 'المنصورة');
      expect(city.adminAr, 'الدقهلية');
    });

    test('a governorate is not repeated after its capital', () {
      // Alexandria city sits in Alexandria governorate: saying it twice reads
      // like a bug, however the two are spelled.
      final city = NearestCityService.nearest(31.2001, 29.9187);

      expect(city!.label('ar'), 'الإسكندرية، مصر');
    });

    test('the English label uses English names', () {
      final city = NearestCityService.nearest(31.0341, 30.4682);

      expect(city!.label('en'), contains('Damanhur'));
      expect(city.label('en'), contains('Egypt'));
    });

    test('cities outside the Arab world are covered too', () {
      expect(NearestCityService.nearest(41.0082, 28.9784)!.countryAr, 'تركيا');
      expect(NearestCityService.nearest(51.5074, -0.1278)!.nameAr, 'لندن');
    });

    test('the middle of an ocean has no name', () {
      expect(NearestCityService.nearest(0, -140), isNull);
    });
  });

  group('Searching by name', () {
    test('finds a city however the alef is spelled', () {
      final loose = NearestCityService.search('الاسكندريه');
      final exact = NearestCityService.search('الإسكندرية');

      expect(loose, isNotEmpty);
      expect(exact, isNotEmpty);
      expect(loose.first.nameAr, exact.first.nameAr);
    });

    test('finds a city by its English name', () {
      expect(NearestCityService.search('Riyadh').first.countryAr, 'السعودية');
    });

    test('a single letter is not a search', () {
      expect(NearestCityService.search('ا'), isEmpty);
    });
  });

  test('the table is big enough to be useful', () {
    expect(NearestCityService.isLoaded, isTrue);
    // Every Arab town above 15k people, plus world cities above 250k.
    expect(NearestCityService.count, greaterThan(3000));
  });
}
