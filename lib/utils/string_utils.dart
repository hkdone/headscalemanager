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
      if (host.contains(RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')) ||
          host == 'localhost') {
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

/// Normalise un nom d'utilisateur en supprimant le domaine de l'e-mail,
/// en le mettant en minuscules et en remplaçant les caractères non-alphanumériques (dont '.') par des tirets.
/// Conforme aux exigences de nommage des tags et groupes Headscale/Tailscale.
///
/// Par exemple:
/// - 'User@example.com' -> 'user'
/// - 'marine.leclerc.pro@gmail.com' -> 'marine-leclerc-pro'
/// - 'Jean.Dupont@synology.me' -> 'jean-dupont'
String normalizeUserName(String userName) {
  final localPart =
      userName.contains('@') ? userName.split('@').first : userName;
  var sanitized = localPart.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
  sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');
  if (sanitized.startsWith('-')) sanitized = sanitized.substring(1);
  if (sanitized.endsWith('-')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }
  return sanitized.isEmpty ? 'user' : sanitized;
}

/// Résout les membres valides pour les groupes Tailscale/Headscale ACL (Policy v2 >= 0.26).
///
/// Règles Headscale strictes :
/// - Un utilisateur OIDC ou basé sur un email est référencé par son email complet.
/// - Un utilisateur dont le `name` contient déjà `@` est conservé tel quel.
/// - Un utilisateur local sans `@` ni email est référencé avec un `@` final vide
///   (`"username@"`, et jamais un domaine inventé), tel qu'exigé par `hscontrol/policy/v2`.
List<String> resolveAclGroupMembers(
  String userName, {
  String? email,
  String? fallbackDomain,
}) {
  final members = <String>{};
  final trimmedEmail = email?.trim() ?? '';
  final trimmedName = userName.trim();

  // 1. Email valide (OIDC ou compte avec email explicite)
  if (trimmedEmail.isNotEmpty && trimmedEmail.contains('@')) {
    members.add(trimmedEmail);
  }

  // 2. Nom d'utilisateur exact : tel quel s'il contient '@', sinon suffixé par '@'
  if (trimmedName.isNotEmpty && trimmedName != 'Unknown User') {
    if (trimmedName.contains('@')) {
      members.add(trimmedName);
    } else {
      members.add('$trimmedName@');
    }
  }

  if (members.isEmpty && trimmedName.isNotEmpty) {
    members.add(trimmedName.contains('@') ? trimmedName : '$trimmedName@');
  }

  return members.toList();
}

/// Validation RFC 1123 pour les sous-domaines DNS.
///
/// Règles :
/// - Contient uniquement des lettres minuscules, chiffres, et tirets.
/// - Ne commence pas ni ne finit par un tiret.
/// - Longueur max 63 caractères.
final RegExp _dns1123Regex = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

bool isValidDns1123Subdomain(String value) {
  return _dns1123Regex.hasMatch(value);
}

// Basic email regex for user name validation
final RegExp _emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

bool isValidEmail(String value) {
  return _emailRegex.hasMatch(value);
}

/// Headscale accepte soit un nom DNS (bob), soit un email (bob@domain.com) selon la config.
bool isValidHeadscaleUser(String value) {
  return isValidDns1123Subdomain(value) || isValidEmail(value);
}

/// Nettoie une chaîne pour la rendre conforme à la RFC 1123.
/// Remplace les caractères invalides par des tirets et s'assure des règles de début/fin.
String sanitizeDns1123Subdomain(String value) {
  var sanitized = value.toLowerCase();

  // Remplace tout ce qui n'est pas a-z, 0-9 par des tirets
  sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9]'), '-');

  // Supprime les tirets multiples (ex: 'te--st' -> 'te-st')
  sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');

  // Supprime les tirets de début et de fin
  if (sanitized.startsWith('-')) sanitized = sanitized.substring(1);
  if (sanitized.endsWith('-')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }

  if (sanitized.length > 63) {
    sanitized = sanitized.substring(0, 63);
    if (sanitized.endsWith('-')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
  }

  return sanitized;
}
