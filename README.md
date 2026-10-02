# autopass

Auto-saisie d'identifiant et de mot de passe pour Linux, basée sur `pass` (GPG).
Raccourci clavier -> fenêtre active -> ligne du coffre -> identifiant, Tab, mot de passe, Entrée.
Rien ne tourne en permanence : le script démarre au raccourci puis s'arrête.

Ce dépôt suppose que vous savez utiliser `pass` et GPG. Sinon, commencer par leur documentation (section « Documentation officielle » en bas).

## Environnements supportés

| Environnement | Détection fenêtre | Saisie | Statut |
|---|---|---|---|
| Hyprland (Wayland) | `hyprctl` + `jq` | `wtype` | testé |
| KDE Plasma (Wayland) | `kdotool` | `dotool` | testé |
| X11 (tout bureau) | `xdotool` + `xprop` | `xdotool` | non testé |

L'environnement est détecté automatiquement.

## Dépendances
- Toujours : `git pass gnupg libnotify`
- Hyprland : `wtype jq`
- KDE Wayland : `kdotool` et `dotool` (AUR). La disposition clavier se règle avec `AUTOPASS_LAYOUT` (`fr` par défaut).
- X11 : `xdotool xorg-xprop`

## Installation

1. Installer les outils (exemple Hyprland)

        sudo pacman -S git pass gnupg libnotify wtype jq

   Exemple KDE Wayland :

        sudo pacman -S git pass gnupg libnotify
        paru -S kdotool dotool

2. Récupérer le code

        git clone https://github.com/Bakugo-root/autopass.git ~/autopass

3. Créer sa clé GPG et initialiser le coffre `pass`. Chaque personne a sa clé et sa passphrase :

        gpg --full-generate-key
        pass init SON_ID_GPG

   Les détails (choix de la clé, passphrase, `pass init`) sont dans la documentation de `pass` et de GPG, liée plus bas.

4. Installer le script

        mkdir -p ~/.local/bin
        ln -sf ~/autopass/autopass ~/.local/bin/autopass

   `ln -sf` crée un **lien symbolique** : `~/.local/bin/autopass` n'est pas une copie, c'est un raccourci vers `~/autopass/autopass`.
   - Un seul fichier réel : après un `git pull`, le raccourci clavier utilise tout de suite la nouvelle version.
   - `-s` demande un lien symbolique, `-f` remplace le lien s'il existe déjà.
   - Vérifier : `ls -l ~/.local/bin/autopass` doit afficher une flèche `->` vers `~/autopass/autopass`.
   - Si le dépôt est déplacé ou supprimé, le lien est cassé : refaire la commande avec le nouveau chemin.
   - Pour lancer `autopass` depuis un terminal (par exemple `autopass --window`), `~/.local/bin` doit être dans le `PATH`.
     En cas de « command not found » : `fish_add_path ~/.local/bin` sous fish, ou `export PATH="$HOME/.local/bin:$PATH"` dans `~/.bashrc` sous bash.
     Le raccourci clavier utilise le chemin complet et n'en a pas besoin.

5. Créer le raccourci clavier. La combinaison est libre : `SUPER+P` et `Ctrl+Alt+A` ne sont que des exemples.
   - Hyprland, dans la config (puis `hyprctl reload`) :

         bind = SUPER, P, exec, ~/.local/bin/autopass

   - KDE : Paramètres système -> Clavier -> Raccourcis -> ajouter une commande `~/.local/bin/autopass`, avec la combinaison de votre choix (par exemple `Ctrl+Alt+A`).

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

## Tester chaque brique

Avant d'utiliser le raccourci, tester séparément la détection de fenêtre et la saisie.

**1. Fenêtre active** : cliquer sur la fenêtre voulue pendant les 3 secondes.

    sleep 3; autopass --window

Doit afficher la classe puis le titre de la fenêtre. C'est aussi la commande qui donne le motif à mettre dans le coffre.

**2. Saisie seule** : cliquer dans un champ texte pendant les 3 secondes. Le texte doit sortir exact.

Hyprland :

    sleep 3; printf '%s' 'moi@example.com' | wtype -

KDE Wayland :

    sleep 3; printf 'type moi@example.com\n' | DOTOOL_XKB_LAYOUT=fr dotool

X11 :

    sleep 3; printf '%s' 'moi@example.com' | xdotool type --file -

- Vérifier surtout `@`, les chiffres et les lettres qui changent d'une disposition de clavier à l'autre.
- Tester aussi dans une application Electron (Discord, VS Code), plus sensible à la saisie rapide.
- Si les caractères sont faux sous KDE, régler `DOTOOL_XKB_LAYOUT` (par exemple `fr`) et éventuellement `DOTOOL_XKB_VARIANT`.

## Utilisation
Cliquer dans le champ identifiant, puis lancer le raccourci. La passphrase GPG est demandée la première fois.

## Sauvegarde de la clé GPG
Sans la clé privée et sa passphrase, le coffre est irrécupérable (réinstallation, disque mort).
La sauvegarder une fois, hors du PC, et ne jamais la mettre dans un dépôt git. La procédure est dans la documentation GPG liée plus bas.

## Dépannage
- **Notification « Aucune règle pour : ... »** : aucun motif ne correspond à la classe ni au titre. Refaire `autopass --window`.
- **Caractères qui apparaissent puis disparaissent** (apps Electron comme Discord) : sous Hyprland, le script tape donc le texte caractère par caractère avec `wtype`.
- **Caractères faux** : ne pas utiliser `ydotool`, qui envoie des codes de touches QWERTY et donne un résultat faux sur un clavier AZERTY.
- **Rien ne se passe sous Hyprland** : vérifier que le bind est chargé (`hyprctl binds | grep autopass`).
- **`dotool` ou `ydotool` ne tape rien, ou erreur de permission** : voir [docs/depannage.md](docs/depannage.md) (accès à `/dev/uinput`).

## Limites et sécurité
- Aucune protection anti-phishing : toute page dont le titre contient le motif déclenche la saisie (comme l'Auto-Type de KeePass).
- Chaque appui déchiffre tout le coffre en mémoire, le temps de trouver la bonne ligne, puis la variable est effacée.
- Le mot de passe passe par l'entrée standard des outils de saisie, donc il n'apparaît jamais dans `ps`, et il n'est jamais écrit sur disque en clair.
- Pas de TOTP / double authentification : le code se tape à la main.
- Le dépôt ne contient aucun secret : le coffre vit dans `~/.password-store`, hors du repo.

## Documentation officielle
- `pass` : <https://www.passwordstore.org/> et <https://wiki.archlinux.org/title/Pass>
- GPG : <https://wiki.archlinux.org/title/GnuPG>
- AUR (installer `kdotool`, `dotool`) : <https://wiki.archlinux.org/title/AUR>
- `wtype` : <https://github.com/atx/wtype>
- `kdotool` : <https://github.com/jinliu/kdotool>
- `dotool` : <https://git.sr.ht/~geb/dotool>
- `xdotool` : <https://github.com/jordansissel/xdotool>
- `jq` : <https://jqlang.github.io/jq/>
- Hyprland : <https://wiki.hyprland.org/>
