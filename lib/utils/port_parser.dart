class PortParser {
  /// Parses a string of ports and port ranges into a list of individual integers.
  /// Examples of valid input: "80", "80,443", "1024-2048", "80,443,1024-2048"
  static List<int> parse(String portString) {
    if (portString.trim().isEmpty || portString.trim() == '*') {
      return []; // Represents all ports
    }

    final ports = <int>{}; // Use a Set to avoid duplicate ports
    final parts = portString.split(',');

    for (final part in parts) {
      final trimmedPart = part.trim();
      if (trimmedPart.isEmpty) continue;

      if (trimmedPart.contains('-')) {
        // It's a range
        final rangeParts = trimmedPart.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0]);
          final end = int.tryParse(rangeParts[1]);

          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              ports.add(i);
            }
          }
        }
      } else {
        // It's a single port
        final port = int.tryParse(trimmedPart);
        if (port != null) {
          ports.add(port);
        }
      }
    }

    return ports.toList()..sort();
  }
}
