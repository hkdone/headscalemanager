import 'package:flutter/material.dart';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _secondaryTextColor = Colors.black54;
const Color _cardBackgroundColor = Colors.white;
const Color _codeBlockColor = Color(0xFFE8E8ED);

/// Écran d'aide de l'application.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Aide et Guide', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          _SectionCard(
            title: 'Bienvenue !',
            children: [
              Text(
                'Cette application vous permet de gérer facilement votre serveur Headscale. Ce guide vous aidera à configurer votre serveur et à utiliser l\'application.',
              ),
            ],
          ),
          _SectionCard(
            title: 'Fonctionnement : API VS CLI (Command Line Interface)',
            children: [
              Text(
                'L\'application utilise des appels directs à l\'API de Headscale pour la majorité des opérations. Certaines actions, génèrent une commande CLI que vous devez exécuter manuellement sur votre client pour des raisons de sécurité et de flexibilité.',
              ),
              SizedBox(height: 16),
              Text('Actions directes (via API) :', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _CodeBlock(
                text:
                    '- Lister les utilisateurs et les nœuds.\n'
                    '- Créer et supprimer des utilisateurs.\n'
                    '- Créer et invalider des clés de pré-authentification.\n'
                    '- Gérer les clés d\'API.\n'
                    '- Déplacer un nœud vers un autre utilisateur.\n'
                    '- Supprimer un nœud.\n'
                    '- Activer/Désactiver les routes (subnets et exit node).',
              ),
            ],
          ),
          _SectionCard(
            title: 'Tutoriel : Ajouter un appareil',
            children: [
              Text('Voici les étapes complètes pour ajouter un nouvel appareil (nœud) à votre réseau Headscale.'),
              SizedBox(height: 16),
              Text('1. Créer un utilisateur', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Si ce n\'est pas déjà fait, allez dans l\'onglet "Utilisateurs" et créez un nouvel utilisateur.'),
              SizedBox(height: 16),
              Text('2. Enregistrer l\'appareil', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('A) Avec une clé de pré-authentification (Recommandé) :\n1. Dans l\'onglet "Utilisateurs", cliquez sur l\'icône de clé et créez une clé pour votre utilisateur.\n2. Copiez la commande `tailscale up ...` fournie.\n3. Exécutez cette commande sur l\'appareil que vous souhaitez ajouter.'),
              SizedBox(height: 8),
              Text('B) Enregistrement via l\'application (pour les clients mobiles) :\n1. Sur le client Tailscale, utilisez un serveur alternatif et entrez l\'URL de votre Headscale.\n2. Dans cette application, allez dans les détails de l\'utilisateur, cliquez sur "Enregistrer un nouvel appareil", et collez l\'URL fournie par le client Tailscale.'),
            ],
          ),
          _SectionCard(
            title: 'Gestion des ACLs',
            children: [
              Text('La section ACLs vous permet de gérer finement qui peut communiquer avec qui.'),
              SizedBox(height: 16),
              Text('Workflow recommandé :', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('1. Récupérez la politique actuelle du serveur ou générez une politique de base stricte.\n'                  '2. Ajoutez des autorisations temporaires si besoin (ex: autoriser un nœud A à parler à un nœud B).\n'                  '3. Générez la politique finale pour la contrôler dans le champ de texte.\n'                  '4. Exportez la politique vers le serveur pour l\'appliquer.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _cardBackgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor),
            ),
            const SizedBox(height: 12),
            ...children.map((child) => DefaultTextStyle(
                  style: const TextStyle(color: _secondaryTextColor, fontSize: 14, height: 1.5),
                  child: child,
                )),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;

  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: _codeBlockColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _primaryTextColor),
      ),
    );
  }
}