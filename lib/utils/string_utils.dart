/// Utility functions for string manipulation.
extension StringUtils on String {
  /// Extracts the base domain from a URL string.
  ///
  /// For example:
  /// - 'https://headscale.example.com:8080' -> 'example.com'
  /// - 'http://localhost:8080' -> 'localhost'
  /// - 'https://sub.domain.co.uk' -> 'domain.co.uk'
  String? extractBaseDomain() {
    try {
      final uri = Uri.parse(this);
      final host = uri.host;

      // Handle IP addresses or localhost
      if (host.contains(RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')) || host == 'localhost') {
        return host;
      }

      // Split by dot and take the last two parts for common domains (e.g., example.com)
      // This is a simplification and might not cover all TLDs (e.g., .co.uk) perfectly.
      final parts = host.split('.');
      if (parts.length >= 2) {
        return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
      }
      return host; // Fallback
    } catch (e) {
      // Handle invalid URL format
      return null;
    }
  }
}

/// Normalise un nom d'utilisateur en supprimant le domaine de l'e-mail et en le mettant en minuscule.
///
/// Par exemple: 'User@example.com' -> 'user'
String normalizeUserName(String userName) {
  return userName.split('@').first.toLowerCase();
}
