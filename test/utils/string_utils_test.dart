import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/utils/string_utils.dart';

void main() {
  group('normalizeUserName', () {
    test('normalise les noms simples sans email', () {
      expect(normalizeUserName('jean'), 'jean');
      expect(normalizeUserName('Jean'), 'jean');
    });

    test('normalise les emails standards', () {
      expect(normalizeUserName('jean@synology.me'), 'jean');
      expect(normalizeUserName('Bob@Example.com'), 'bob');
    });

    test('normalise les emails avec points multiples (cas OIDC)', () {
      expect(
        normalizeUserName('marine.leclerc.pro@gmail.com'),
        'marine-leclerc-pro',
      );
      expect(
        normalizeUserName('first.middle.last@domain.org'),
        'first-middle-last',
      );
    });

    test('remplace les caractères spéciaux et évite les tirets consécutifs', () {
      expect(normalizeUserName('john_doe+test@gmail.com'), 'john-doe-test');
      expect(normalizeUserName('..alice--bob..'), 'alice-bob');
    });

    test('fournit un repli sur user si chaîne vide ou uniquement caractères spéciaux', () {
      expect(normalizeUserName(''), 'user');
      expect(normalizeUserName('...'), 'user');
      expect(normalizeUserName('@gmail.com'), 'user');
    });
  });

  group('resolveAclGroupMembers', () {
    test('utilise l\'email si présent et le nom local avec @ (cas OIDC Marine Leclerc)', () {
      final members = resolveAclGroupMembers(
        'marine',
        email: 'marine.leclerc.pro@gmail.com',
      );
      expect(members, contains('marine.leclerc.pro@gmail.com'));
      expect(members, contains('marine@'));
      expect(members.contains('marine'), isFalse);
      for (final m in members) {
        expect(m.contains('@'), isTrue, reason: 'Tailscale/Headscale exige @ dans chaque membre');
      }
    });

    test('utilise le nom si déjà sous format email', () {
      final members = resolveAclGroupMembers('jean@synology.me');
      expect(members, ['jean@synology.me']);
    });

    test('utilise username@ (Policy v2) pour un utilisateur local sans @ ni email', () {
      final members = resolveAclGroupMembers('localuser', fallbackDomain: 'mydomain.com');
      expect(members, ['localuser@']);
    });

    test('tous les membres produits contiennent impérativement @', () {
      final testCases = [
        ('alice', 'alice@gmail.com', null),
        ('bob', null, 'headscale.local'),
        ('claire@test.fr', null, null),
        ('david', '', 'domain.com'),
      ];

      for (final (name, email, domain) in testCases) {
        final res = resolveAclGroupMembers(name, email: email, fallbackDomain: domain);
        expect(res, isNotEmpty);
        for (final m in res) {
          expect(m, contains('@'));
        }
      }
    });
  });
}
