# Dépannage : accès à /dev/uinput

Ce problème ne concerne que les outils de saisie qui passent par `/dev/uinput` :
`dotool` (KDE Wayland) et `ydotool`. Sous Hyprland avec `wtype` ou sous X11 avec `xdotool`, rien à faire ici.

## Symptômes
- `dotool` ou `ydotool` ne tape rien, ou affiche une erreur de permission
- `ydotoold` s'arrête aussitôt (`status=2`) ou le socket `/run/user/UID/.ydotool_socket` n'existe pas

## Diagnostic

    ls -l /dev/uinput
    getfacl /dev/uinput

Par défaut, `/dev/uinput` appartient à `root` et l'utilisateur n'a pas accès.
La sortie de `getfacl` doit contenir une ligne `user:VOTRE_UTILISATEUR:rw-`. Si elle manque, il faut appliquer la règle ci-dessous.

## Correction

    echo 'KERNEL=="uinput", MODE="0660", GROUP="input", TAG+="uaccess", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/70-uinput.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=uinput
    getfacl /dev/uinput

- La règle donne à l'utilisateur connecté un accès à `/dev/uinput` (tag `uaccess`), sans l'ajouter au groupe `input`.
  Ce groupe permet de lire toutes les frappes clavier de la machine, ce qui est à éviter pour un gestionnaire de mots de passe.
- **Le numéro du fichier compte** : il doit être inférieur à 73. Avec un `80-...`, le tag `uaccess` est posé trop tard et ne s'applique pas
  (le groupe change mais la ligne `user:...` n'apparaît pas).
- Après la correction, `getfacl` doit afficher `user:VOTRE_UTILISATEUR:rw-`.
- Si l'accès est toujours refusé, se déconnecter puis se reconnecter.

## Annuler la correction

    sudo rm -f /etc/udev/rules.d/70-uinput.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=uinput

`/dev/uinput` reprend ses droits d'origine.
