import 'dart:ui';
extension AppLocaleFlagExtension on Locale {
  String flag() {
    final code = countryCode?.toUpperCase();

    if (code == null || code.length != 2) {
      return '🌐';
    }

    return code
        .codeUnits
        .map((char) => String.fromCharCode(char + 127397))
        .join();
  }

  String name() {
    switch (languageCode.toLowerCase()) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      case 'es':
        return 'Español';
      case 'it':
        return 'Italiano';
      case 'pt':
        return 'Português';
      case 'ru':
        return 'Русский';
      case 'ar':
        return 'العربية';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';

      case 'nl':
        return 'Nederlands';
      case 'pl':
        return 'Polski';
      case 'uk':
        return 'Українська';
      case 'el':
        return 'Ελληνικά';
      case 'bg':
        return 'Български';
      case 'ro':
        return 'Română';
      case 'hu':
        return 'Magyar';
      case 'cs':
        return 'Čeština';
      case 'sk':
        return 'Slovenčina';
      case 'sl':
        return 'Slovenščina';
      case 'hr':
        return 'Hrvatski';
      case 'sr':
        return 'Српски';
      case 'bs':
        return 'Bosanski';
      case 'sq':
        return 'Shqip';
      case 'mk':
        return 'Македонски';

      case 'sv':
        return 'Svenska';
      case 'no':
        return 'Norsk';
      case 'da':
        return 'Dansk';
      case 'fi':
        return 'Suomi';
      case 'is':
        return 'Íslenska';

      case 'et':
        return 'Eesti';
      case 'lv':
        return 'Latviešu';
      case 'lt':
        return 'Lietuvių';

      case 'ga':
        return 'Gaeilge';
      case 'cy':
        return 'Cymraeg';
      case 'mt':
        return 'Malti';

      case 'ca':
        return 'Català';
      case 'eu':
        return 'Euskara';
      case 'gl':
        return 'Galego';

      case 'he':
        return 'עברית';
      case 'fa':
        return 'فارسی';
      case 'ur':
        return 'اردو';

      case 'hi':
        return 'हिन्दी';
      case 'bn':
        return 'বাংলা';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'ml':
        return 'മലയാളം';
      case 'kn':
        return 'ಕನ್ನಡ';
      case 'mr':
        return 'मराठी';
      case 'gu':
        return 'ગુજરાતી';
      case 'pa':
        return 'ਪੰਜਾਬੀ';
      case 'ne':
        return 'नेपाली';
      case 'si':
        return 'සිංහල';

      case 'th':
        return 'ไทย';
      case 'vi':
        return 'Tiếng Việt';
      case 'id':
        return 'Bahasa Indonesia';
      case 'ms':
        return 'Bahasa Melayu';
      case 'fil':
      case 'tl':
        return 'Filipino';

      case 'az':
        return 'Azərbaycan dili';
      case 'ka':
        return 'ქართული';
      case 'hy':
        return 'Հայերեն';
      case 'kk':
        return 'Қазақша';
      case 'uz':
        return 'Oʻzbekcha';
      case 'tk':
        return 'Türkmençe';
      case 'ky':
        return 'Кыргызча';
      case 'mn':
        return 'Монгол';

      case 'sw':
        return 'Kiswahili';
      case 'af':
        return 'Afrikaans';
      case 'zu':
        return 'isiZulu';
      case 'xh':
        return 'isiXhosa';
      case 'am':
        return 'አማርኛ';
      case 'so':
        return 'Soomaali';
      case 'ha':
        return 'Hausa';
      case 'yo':
        return 'Yorùbá';
      case 'ig':
        return 'Igbo';

      case 'la':
        return 'Latina';
      case 'eo':
        return 'Esperanto';

      default:
        return languageCode.toUpperCase();
    }
  }
}