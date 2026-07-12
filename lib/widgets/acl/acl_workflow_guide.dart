import 'package:flutter/material.dart';

/// Indicateur compact + aide contextuelle pour le mode brouillon local.
class AclWorkflowGuide extends StatelessWidget {
  final bool isFr;

  const AclWorkflowGuide({super.key, required this.isFr});

  static Future<void> showHelpDialog(BuildContext context, {required bool isFr}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFr ? 'Brouillon local' : 'Local draft',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFr
                    ? 'Le serveur n\'a pas été modifié. Vous pouvez tester sans risque.'
                    : 'The server has not been changed. You can test safely.',
              ),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Que faire :' : 'What to do:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _stepText(
                isFr,
                '1',
                isFr
                    ? '« Composer une règle » — inutile d\'effacer vos ACL/grants existants'
                    : '« Compose a rule » — no need to erase existing ACLs/grants',
              ),
              _stepText(
                isFr,
                '2',
                isFr
                    ? 'Ajoutez vos grants (onglet Grants)'
                    : 'Add your grants (Grants tab)',
              ),
              _stepText(
                isFr,
                '3',
                isFr
                    ? 'Supprimez « tout autoriser » (onglet ACLs) si présent'
                    : 'Remove « allow all » (ACLs tab) if present',
              ),
              _stepText(
                isFr,
                '4',
                isFr
                    ? 'Menu ⋮ > « Exporter vers le serveur » pour publier'
                    : '⋮ menu > « Export to Server » to publish',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isFr ? 'Compris' : 'Got it'),
          ),
        ],
      ),
    );
  }

  static Widget _stepText(bool isFr, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number.', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text(
            isFr ? 'Brouillon local' : 'Local draft',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade800,
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, size: 20, color: Colors.amber.shade800),
            tooltip: isFr ? 'Aide brouillon' : 'Draft help',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => showHelpDialog(context, isFr: isFr),
          ),
        ],
      ),
    );
  }
}
