import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

// shadcn_flutter does not ship a Belarusian locale yet. The app's own strings
// are translated in ARB files; internal control strings use English meanwhile.
class PovadShadcnDelegate
    extends LocalizationsDelegate<shad.ShadcnLocalizations> {
  const PovadShadcnDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'be';

  @override
  Future<shad.ShadcnLocalizations> load(Locale locale) =>
      SynchronousFuture(shad.ShadcnLocalizationsEn(locale.languageCode));

  @override
  bool shouldReload(PovadShadcnDelegate old) => false;
}
