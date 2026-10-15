/// Brend resurslary.
///
/// Ikonany täzelemek: `assets/branding/app_icon.png` çalyşyp,
/// `python tools/build_app_icons.py` işlediň (Android mipmap-lary hem
/// şol faýldan öndürilýär).
class Branding {
  const Branding._();

  /// Programma görnüşindäki ikona (açylyş ekrany, "barada" bölümi).
  static const String appIconAsset = 'assets/branding/app_icon_512.png';

  /// Play Store / paýlaşmak üçin uly nusga.
  static const String storeIconAsset = 'assets/branding/app_icon_512.png';
}

const String kAppIconAsset = Branding.appIconAsset;
