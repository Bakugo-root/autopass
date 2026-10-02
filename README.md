# autopass

Auto-saisie d'identifiant et de mot de passe pour Arch Linux / Hyprland, basée sur `pass`.
Raccourci clavier -> fenêtre active -> ligne du coffre -> identifiant, Tab, mot de passe, Entrée.

## Dépendances
`pass`, `wtype`, `jq`, `libnotify`

## Installation
    ln -sf ~/autopass/autopass ~/.local/bin/autopass

Raccourci Hyprland :

    bind = SUPER, P, exec, ~/.local/bin/autopass

## Coffre
Une seule entrée chiffrée, une ligne par compte (`motif;identifiant;mot_de_passe`) :

    pass edit autopass/vault

Le motif est comparé à la classe de la fenêtre (égalité), sinon à son titre (contenu).
