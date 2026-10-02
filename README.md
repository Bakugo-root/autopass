# autopass

Auto-saisie d'identifiant et de mot de passe pour Arch Linux / Hyprland, basée sur `pass` (GPG).
Raccourci clavier -> fenêtre active -> ligne du coffre -> identifiant, Tab, mot de passe, Entrée.
Rien ne tourne en permanence : le script démarre au raccourci puis s'arrête.

## Prérequis
- Arch Linux, Wayland, **Hyprland** (le script utilise `hyprctl`)
- Paquets : `git pass gnupg wtype jq libnotify`

## Installation

1. Installer les outils

        sudo pacman -S git pass gnupg wtype jq libnotify

2. Récupérer le code

        git clone https://github.com/Bakugo-root/autopass.git ~/autopass

3. Créer sa clé GPG et le coffre `pass` (chaque personne a sa clé et sa passphrase)

        gpg --full-generate-key
        gpg --list-secret-keys --keyid-format long
        pass init SON_MAIL

4. Installer le script

        mkdir -p ~/.local/bin
        ln -sf ~/autopass/autopass ~/.local/bin/autopass

5. Ajouter le raccourci dans la config Hyprland (puis `hyprctl reload`)

        bind = SUPER, P, exec, ~/.local/bin/autopass

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

    sleep 3; hyprctl activewindow -j | jq '.class,.title'

## Utilisation
Cliquer dans le champ identifiant, puis `SUPER+P`. La passphrase GPG est demandée la première fois.

## Dépannage
- **Notification « Aucune règle pour : ... »** : aucun motif ne correspond à la classe ni au titre. Refaire la commande `hyprctl` ci-dessus.
- **Caractères qui apparaissent puis disparaissent** (apps Electron comme Discord) : c'est pourquoi le script tape le texte caractère par caractère, avec un `wtype` par caractère.
- **Caractères faux** : ne pas utiliser `ydotool`, qui envoie des codes de touches QWERTY et donne un résultat faux sur un clavier AZERTY.
- **Rien ne se passe** : vérifier que le bind est chargé (`hyprctl binds | grep autopass`).

## Limites et sécurité
- Aucune protection anti-phishing : toute page dont le titre contient le motif déclenche la saisie (comme l'Auto-Type de KeePass).
- Chaque appui déchiffre tout le coffre en mémoire, le temps de trouver la bonne ligne, puis la variable est effacée.
- Le mot de passe passe par l'entrée standard de `wtype`, donc il n'apparaît jamais dans `ps`, et il n'est jamais écrit sur disque en clair.
- Pas de TOTP / double authentification : le code se tape à la main.
- Le dépôt ne contient aucun secret : le coffre vit dans `~/.password-store`, hors du repo.
