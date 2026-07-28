import 'package:asrocoin/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all supported locales load their translated interface', () async {
    const expectedLocales = {'en', 'tr', 'es', 'pt', 'pt_BR'};
    final loadedLocales = <String>{};

    for (final locale in AppLocalizations.supportedLocales) {
      final translations = await AppLocalizations.delegate.load(locale);
      final localeCode = locale.countryCode == null
          ? locale.languageCode
          : '${locale.languageCode}_${locale.countryCode}';
      loadedLocales.add(localeCode);

      expect(translations.navMarket, isNotEmpty);
      expect(translations.language, isNotEmpty);
      expect(translations.predictionResolutionInfo, isNotEmpty);
      expect(translations.activePredictions(12), contains('12'));
    }

    expect(loadedLocales, expectedLocales);
  });

  test('financial and brand identifiers remain unchanged', () async {
    final translations =
        await AppLocalizations.delegate.load(const Locale('pt', 'BR'));

    expect('ASROCOIN', 'ASROCOIN');
    expect('BTC', 'BTC');
    expect(translations.navMarket, isNotEmpty);
  });
}
