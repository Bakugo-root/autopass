# autopass

Auto-saisie d'identifiant et de mot de passe pour Linux, basée sur `pass` (GPG).
Raccourci clavier -> fenêtre active -> ligne du coffre -> identifiant, Tab, mot de passe, Entrée.
Rien ne tourne en permanence : le script démarre au raccourci puis s'arrête.

## Environnements supportés

| Environnement | Détection fenêtre | Saisie | Statut |
|---|---|---|---|
| Hyprland (Wayland) | `hyprctl` + `jq` | `wtype` | testé |
| KDE Plasma (Wayland) | `kdotool` | `dotool` | non testé |
| X11 (tout bureau) | `xdotool` + `xprop` | `xdotool` | non testé |

L'environnement est détecté automatiquement.

## Dépendances
- Toujours : `git pass gnupg libnotify`
- Hyprland : `wtype jq`
- KDE Wayland : `kdotool` et `dotool` (AUR). `dotool` a besoin d'un accès à `/dev/uinput` (voir sa documentation).
  La disposition clavier se règle avec `AUTOPASS_LAYOUT` (`fr` par défaut).
- X11 : `xdotool xorg-xprop`

## Installation

1. Installer les outils (exemple Hyprland)

        sudo pacman -S git pass gnupg libnotify wtype jq

2. Récupérer le code

        git clone https://github.com/Bakugo-root/autopass.git ~/autopass

3. Créer sa clé GPG et le coffre `pass` (chaque personne a sa clé et sa passphrase)

        gpg --full-generate-key
        gpg --list-secret-keys --keyid-format long
        pass init SON_MAIL

4. Installer le script

        mkdir -p ~/.local/bin
        ln -sf ~/autopass/autopass ~/.local/bin/autopass

5. Créer le raccourci clavier
   - Hyprland, dans la config (puis `hyprctl reload`) :

         bind = SUPER, P, exec, ~/.local/bin/autopass

   - KDE : Paramètres système -> Raccourcis -> ajouter une commande `~/.local/bin/autopass`.

## Le coffre

Une seule entrée chiffrée, une ligne par compte, au format `motif;identifiant;mot_de_passe` :

    env EDITOR=nano pass edit autopass/vault

Exemple (faux comptes) :

    discord;moi@example.com;motdepasse1
    Discord;moi@example.com;motdepasse1
    Sign in to GitHub;mon_pseudo;motdepasse2

- Le motif est comparé à la **classe** de la fenêtre (égalité), sinon à son **titre** (le motif y est contenu).
- Une application native a une classe (`discord`), un site dans Firefox se reconnaît à son titre (`Discord`).
- La première ligne qui correspond gagne, donc l'ordre compte.
- Les lignes vides et celles qui commencent par `#` sont ignorées.
- Le mot de passe est tout ce qui suit le 2e `;` (il peut contenir des `;`). Le motif et l'identifiant ne doivent pas en contenir.

Pour trouver le bon motif d'une fenêtre (cliquer dessus pendant les 3 secondes) :

    sleep 3; autopass --window

## Utilisation
Cliquer dans le champ identifiant, puis lancer le raccourci. La passphrase GPG est demandée la première fois.

## Dépannage
- **Notification « Aucune règle pour : ... »** : aucun motif ne correspond à la classe ni au titre. Refaire `autopass --window`.
- **Caractères qui apparaissent puis disparaissent** (apps Electron comme Discord) : le script tape donc le texte caractère par caractère avec `wtype`.
- **Caractères faux** : ne pas utiliser `ydotool`, qui envoie des codes de touches QWERTY et donne un résultat faux sur un clavier AZERTY.
- **Rien ne se passe sous Hyprland** : vérifier que le bind est chargé (`hyprctl binds | grep autopass`).

## Limites et sécurité
- Aucune protection anti-phishing : toute page dont le titre contient le motif déclenche la saisie (comme l'Auto-Type de KeePass).
- Chaque appui déchiffre tout le coffre en mémoire, le temps de trouver la bonne ligne, puis la variable est effacée.
- Le mot de passe passe par l'entrée standard des outils de saisie, donc il n'apparaît jamais dans `ps`, et il n'est jamais écrit sur disque en clair.
- Pas de TOTP / double authentification : le code se tape à la main.
- Le dépôt ne contient aucun secret : le coffre vit dans `~/.password-store`, hors du repo.
