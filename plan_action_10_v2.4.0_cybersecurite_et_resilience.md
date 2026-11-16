# Plan d'Action 10 — Version 2.4.0 : Durcissement Cybersécurité & Résilience Réseau

**Date de création** : 16 novembre 2026  
**Version cible** : `2.4.0+158`  
**Branche Git dédiée** : `sec/v2.4.0-cybersecurity-network-hardening` *(créée depuis `master`)*  
**Prérequis** : Indépendant *(recommandé après Plan 08)*  
**Priorité** : **P1 — Haute (Sécurité OWASP Mobile & Remédiation Audit SAST)**  
**Niveau de risque global** : 🟢 **Faible** *(durcissement côté client uniquement, aucune modification du protocole ou des ACLs serveur)*

---

## 1. Objectif

Protéger la clé API maître de l'administrateur et corriger les faiblesses cryptographiques, réseau et SAST identifiées dans l'audit du code :

1. **Renforcer l'authentification locale par code PIN** : remplacer le SHA-256 non salé par **PBKDF2-HMAC-SHA256 avec sel aléatoire** + protection anti-bruteforce.
2. **Ajouter le re-verrouillage automatique en arrière-plan** lorsque l'application est quittée/mise en veille.
3. **Sécuriser les communications API** : ajout de timeouts HTTP, alerte critique sur l'utilisation de `http://` non chiffré sur Internet, assainissement des logs d'erreurs.
4. **Respecter la confidentialité réseau** dans `NetworkOverviewScreen` (suppression des requêtes automatiques non sollicitées vers `api.ipify.org` et `8.8.8.8`).
5. **Résoudre les 3 alertes restantes de [audit-report-headscalemanager.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/audit-report-headscalemanager.md)** (blocs `catch (_) {}` silencieux dans `SecurityService`, `StorageService` et `AclScreen`) et compléter `.gitignore`.

---

## 2. Prise en compte de la Production Hétérogène (Zéro Lockout Utilisateur)

> [!IMPORTANT]
> **Migration Transparente du PIN (Zéro blocage pour les utilisateurs existants) :**
> Les utilisateurs actuels ont déjà un PIN stocké en `SHA-256` pur (sans sel). Changer brutalement l'algorithme leur refuserait l'accès à leur propre application !
> **Stratégie mise en place :**
> - Lors de `verifyPin()`, si la clé `APP_PIN_SALT` est absente, l'application vérifie d'abord l'ancien hash `SHA-256`.
> - Si le PIN est valide, elle génère immédiatement un sel aléatoire de 16 octets (`Random.secure()`), calcule le nouveau hash **PBKDF2-HMAC-SHA256**, et met à jour le stockage sécurisé de façon totalement transparente.

---

## 3. Détails Techniques

### Tâche 10.1 — PIN PBKDF2 Salé, Comparaison Temps Constant & Anti-Bruteforce
- Dans `lib/services/security_service.dart` :
  - Implémenter PBKDF2-HMAC-SHA256 (en utilisant `Hmac(sha256, ...)` du package `crypto` déjà présent dans `pubspec.yaml`, 10 000 itérations, sel de 16 octets via `Random.secure()`).
  - Implémenter une comparaison octet par octet en temps constant (`_constantTimeEquals`).
  - Assurer la migration automatique depuis l'ancien hash `SHA-256` lors du premier déverrouillage réussi.
  - Persister les échecs (`APP_PIN_FAILED_ATTEMPTS`, `APP_PIN_LOCKOUT_UNTIL`) :
    - 5 échecs consécutifs $\rightarrow$ blocage de 30 secondes.
    - 10 échecs consécutifs $\rightarrow$ blocage de 5 minutes.
- Dans `lib/screens/lock_screen.dart` : afficher un compte à rebours clair en cas de verrouillage temporaire et désactiver le pavé numérique pendant le délai.
- Dans `lib/screens/setup_pin_screen.dart` : supporter un PIN de 4 à 6 chiffres (rétrocompatible 4 chiffres).

### Tâche 10.2 — Verrouillage Automatique en Arrière-Plan
- Dans `lib/main.dart` : ajouter un `AppLifecycleListener` / `WidgetsBindingObserver` autour du widget racine.
- Enregistrer l'horodatage lors du passage en `AppLifecycleState.paused`.
- Au retour en `AppLifecycleState.resumed`, si un PIN est configuré, que le verrouillage arrière-plan est activé, et que la durée écoulée dépasse le délai configuré (défaut conservateur pour ne pas gêner les utilisateurs existants : *5 minutes*, options : *Immédiat / 1 min / 5 min / Au démarrage uniquement*), afficher `LockScreen` en modal par-dessus l'écran courant afin de ne pas perdre le formulaire en cours.
- Ajouter un drapeau `SecurityService.suppressNextResumeLock` pendant les appels à `LocalAuthentication`, `FilePicker` et `ImagePicker` pour éviter une boucle de verrouillage OS.

### Tâche 10.3 — Timeouts HTTP, Alerte HTTP Non Chiffré & Remédiation SAST
- Dans `lib/api/headscale_api_service.dart` :
  - Appliquer `.timeout(const Duration(seconds: 20))` sur toutes les requêtes HTTP.
  - Tronquer les réponses d'erreur HTML longues (ex: 502 Bad Gateway) et ne jamais logger de clé API.
- Dans `lib/screens/add_edit_server_screen.dart` :
  - Détecter les URLs en `http://` pointant hors réseau local/VPN (`localhost`, `127.0.0.1`, `10.x`, `192.168.x`, `100.64.0.0/10`) et exiger une confirmation explicite via dialogue d'alerte sécurité avant sauvegarde.
- Remédiation des 3 alertes de `audit-report-headscalemanager.md` :
  - `lib/services/security_service.dart` (lignes 29, 36) et `lib/services/storage_service.dart` (lignes 391, 398) : remplacer `catch (_) {}` par une journalisation maîtrisée (`debugPrint` du type d'exception uniquement, jamais de valeur/clé) et une remontée d'état d'erreur si critique.
  - `lib/screens/acl_screen.dart` (ligne 157) : capturer explicitement l'erreur lors de `getUsers()` et afficher un retour utilisateur si la liste est vide.
  - `.gitignore` : ajouter `*.keystore` et exclure les artefacts `android/.gradle/`.

### Tâche 10.4 — Confidentialité sur `NetworkOverviewScreen`
- Dans `lib/screens/network_overview_screen.dart` :
  - Ne plus appeler `https://api.ipify.org` ni lancer de traceroute `8.8.8.8` automatiquement au chargement de la page.
  - Remplacer par un bouton d'action explicite *"Tester la sortie Internet (IP publique & Traceroute)"* avec sélecteur de cible (`1.1.1.1`, `8.8.8.8`, `9.9.9.9`).

---

## 4. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Modifié** | `lib/services/security_service.dart` | PBKDF2 + sel, migration transparente, anti-bruteforce, remédiation SAST |
| **Modifié** | `lib/screens/lock_screen.dart` | Affichage lockout + blocage temporaire |
| **Modifié** | `lib/screens/setup_pin_screen.dart` | Support optionnel 4–6 chiffres |
| **Modifié** | `lib/screens/security_settings_screen.dart` | Réglage du délai de re-verrouillage arrière-plan |
| **Modifié** | `lib/main.dart` | Observateur `AppLifecycleState` pour re-verrouillage |
| **Modifié** | `lib/api/headscale_api_service.dart` | Timeouts 20s + assainissement erreurs |
| **Modifié** | `lib/screens/add_edit_server_screen.dart` | Alerte explicite si URL `http://` publique |
| **Modifié** | `lib/services/storage_service.dart` | Remédiation SAST blocs `catch` vides |
| **Modifié** | `lib/screens/acl_screen.dart` | Remédiation SAST ligne 157 |
| **Modifié** | `lib/screens/network_overview_screen.dart` | Diagnostic externe opt-in au clic |
| **Modifié** | `.gitignore` | Ajout `*.keystore` et exclusions Gradle |
| **Tests** | `test/services/security_service_test.dart` | Tests migration PIN, PBKDF2 et lockout *(Nouveau)* |

---

## 5. Risques de Casse & Procédure de Rollback

| Risque identifié | Probabilité | Impact | Mitigation |
|---|---|---|---|
| **Blocage d'un utilisateur ayant un ancien PIN SHA-256** | Très Faible | Critique | Fallback explicite sur `sha256` si `APP_PIN_SALT` est null, couvert par un test unitaire dédié avant merge. |
| **Re-verrouillage intempestif lors d'un `FilePicker` / biométrie** | Moyen | Faible | Drapeau `suppressNextResumeLock` + délai par défaut de 5 minutes. |
| **Timeout 20s trop court sur serveur distant très lent** | Très Faible | Faible | Timeout porté à 20s avec message explicite invitant à réessayer. |

### Commandes Git de branche & rollback :
```bash
# Création de la branche depuis master
git checkout master && git pull
git checkout -b sec/v2.4.0-cybersecurity-network-hardening

# Rollback immédiat avant merge
git checkout master
git branch -D sec/v2.4.0-cybersecurity-network-hardening

# Rollback après merge
git revert -m 1 <commit_merge_sha>
```
