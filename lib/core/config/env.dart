class Env {
  static const String _defaultUrl = 'https://api.greenrevs.com';
  static const String _defaultSiteUrl = 'https://www.greenrevs.com';

  static String get apiBaseUrl {
    const overrideUrl = String.fromEnvironment('API_BASE_URL');
    if (overrideUrl.isNotEmpty) {
      return overrideUrl.replaceAll(RegExp(r'/$'), '');
    }
    return _defaultUrl;
  }

  /// The public website — hosts the AI concierge route and the vendor/expert dashboards.
  static String get siteBaseUrl {
    const overrideUrl = String.fromEnvironment('SITE_BASE_URL');
    if (overrideUrl.isNotEmpty) {
      return overrideUrl.replaceAll(RegExp(r'/$'), '');
    }
    return _defaultSiteUrl;
  }
}
