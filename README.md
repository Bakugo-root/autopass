# autopass

Auto-saisie d'identifiant et de mot de passe pour Arch Linux / Hyprland, basée sur `pass`.
Raccourci clavier -> fenêtre active -> règle -> `pass show` -> identifiant, Tab, mot de passe, Entrée.

## Dépendances
`pass`, `wtype`, `jq`, `libnotify`

## Installation
    cp autopass ~/.local/bin/
    mkdir -p ~/.config/autopass
    cp rules.conf.example ~/.config/autopass/rules.conf

Dans la config Hyprland :

    bind = SUPER, P, exec, ~/.local/bin/autopass
