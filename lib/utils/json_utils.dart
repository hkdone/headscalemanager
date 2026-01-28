class JsonUtils {
  /// Nettoie une chaîne JSON contenant des commentaires (HuJSON) pour la rendre compatible avec le parser strict de Dart.
  /// Enlève les commentaires de ligne commençant par //
  static String cleanJsonComments(String jsonString) {
    if (jsonString.isEmpty) return jsonString;

    final buffer = StringBuffer();
    final lines = jsonString.split('\n');

    for (var line in lines) {
      // Expression régulière pour trouver // qui n'est pas dans une chaîne de caractères
      // C'est complexe à faire parfaitement en une regex simple, donc on va faire une approche pragmatique
      // pour les fichiers de config Headscale : on suppose que // marque le début d'un commentaire
      // sauf si c'est une URL (http://...).
      //
      // Une approche plus robuste ligne par ligne :
      int commentIndex = line.indexOf('//');

      // Si on trouve un //
      if (commentIndex != -1) {
        // Vérification basique pour ne pas casser les URLs (http://, https://)
        bool isUrl = false;
        if (commentIndex > 0 && line[commentIndex - 1] == ':') {
          // Probablement une URL type "http://"
          isUrl = true;
        }

        if (!isUrl) {
          // On garde tout ce qui est avant le commentaire
          buffer.writeln(line.substring(0, commentIndex));
        } else {
          // C'était une URL, on garde la ligne (ou on cherche un autre // plus loin ?
          // Pour l'instant on garde la ligne telle quelle, cas rare dans les ACLs sauf pour les hosts)
          buffer.writeln(line);
        }
      } else {
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }
}
