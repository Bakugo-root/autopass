#!/usr/bin/env bash
# Tests d'autopass avec de faux outils (wtype, pass, hyprctl, wl-copy, cliphist...).
# Ne touche ni à ton vrai coffre ni à ton presse-papier. Usage : tests/run.sh
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/store/autopass"
export T

# ---------- faux outils ----------
mock() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }

mock hyprctl 'cat "$T/win.json"'
mock wtype 'if [ "$1" = "-" ]; then echo "TYPE:$(cat)" >>"$T/log"; else echo "KEY:$2" >>"$T/log"; fi
[ ! -e "$T/wtype_fail" ]'
mock pass 'case $1 in
  show) [ -e "$T/pass_fail" ] && exit 1; cat "$T/vault" ;;
  insert) cat >"$T/vault"; echo INSERT >>"$T/log" ;;
esac'
mock notify-send 'echo "NOTIFY:$2" >>"$T/log"'
mock menu 'cat >"$T/menu_in"
[ -e "$T/menu_switch" ] && cp "$T/menu_switch" "$T/win.json"
[ -n "${MENU_CHOICE:-}" ] || exit 1
sed -n "${MENU_CHOICE}p" "$T/menu_in"'
mock wl-copy 'if [ "${1:-}" = "--clear" ]; then rm -f "$T/clip"; echo CLIPCLEAR >>"$T/log"
else [ "${1:-}" = "--sensitive" ] && echo SENSITIVE >>"$T/log"; cat >"$T/clip"; fi'
mock wl-paste '[ -f "$T/clip" ] && cat "$T/clip" || exit 1'
mock cliphist 'case $1 in
  list) cat "$T/hist" ;;
  delete) cat >"$T/deleted"; grep -vxFf "$T/deleted" "$T/hist" >"$T/hist.new"; mv "$T/hist.new" "$T/hist" ;;
esac'

export PATH="$T/bin:$PATH"
export HYPRLAND_INSTANCE_SIGNATURE=test
export PASSWORD_STORE_DIR="$T/store"
export AUTOPASS_MENU="$T/bin/menu"
export AUTOPASS_ADD_DELAY=0
export AUTOPASS_CLEAR_DELAY=1
unset DISPLAY XDG_SESSION_TYPE

# ---------- helpers ----------
pass_n=0; fail_n=0
ok()   { pass_n=$((pass_n + 1)); printf '  ok   %s\n' "$1"; }
ko()   { fail_n=$((fail_n + 1)); printf '  ECHEC %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else ko "$1" "attendu [$3] obtenu [$2]"; fi; }
has()  { if [[ $2 == *"$3"* ]]; then ok "$1"; else ko "$1" "[$3] absent de [$2]"; fi; }
hasnt(){ if [[ $2 != *"$3"* ]]; then ok "$1"; else ko "$1" "[$3] présent dans [$2]"; fi; }

win()   { printf '{"class":"%s","title":"%s"}\n' "$1" "$2" >"$T/win.json"; }
vault() { printf '%s\n' "$1" >"$T/vault"; touch "$T/store/autopass/vault.gpg"; }
reset() { : >"$T/log"; rm -f "$T/pass_fail" "$T/menu_switch" "$T/clip" "$T/wtype_fail" "$T/hist"; unset MENU_CHOICE; }
# journal lisible : texte tapé, <tab>, <enter>, [NOTIFY ...]
typed() {
  local out="" l
  while IFS= read -r l; do
    case $l in
      TYPE:*)       out+=${l#TYPE:} ;;
      KEY:Tab)      out+='<tab>' ;;
      KEY:Return)   out+='<enter>' ;;
      NOTIFY:*)     out+="[${l#NOTIFY:}]" ;;
      *)            out+="{$l}" ;;
    esac
  done <"$T/log"
  printf '%s' "$out"
}
run() { out=$("$root/autopass" "$@" 2>&1); rc=$?; }

echo "== saisie de base =="
reset; win discord "Discord"; vault 'discord;moi@ex.com;mdp1'
run; eq "séquence par défaut" "$(typed)" 'moi@ex.com<tab>mdp1<enter>'

reset; vault 'discord{pass,enter};;123456'
run; eq "séquence {pass,enter}, identifiant vide" "$(typed)" '123456<enter>'

reset; vault 'discord{ USER , Tab,pass };moi;secret'
run; eq "espaces et casse ignorés dans la séquence" "$(typed)" 'moi<tab>secret'

reset; vault 'discord;moi;a;b;c'
run; eq "mot de passe contenant des ;" "$(typed)" 'moi<tab>a;b;c<enter>'

reset; vault '# commentaire

discord;moi;x'
run; eq "commentaires et lignes vides ignorés" "$(typed)" 'moi<tab>x<enter>'

echo "== correspondance =="
reset; win firefox "Sign in to GitHub — Mozilla Firefox"; vault 'sign in to github;gh;pw'
run; eq "titre contenu, insensible à la casse" "$(typed)" 'gh<tab>pw<enter>'

reset; win DISCORD "x"; vault 'discord;moi;pw'
run; eq "classe égale, insensible à la casse" "$(typed)" 'moi<tab>pw<enter>'

reset; win firefox "Connexion GitLab"; vault 're:^git(hub|lab)$|gitlab;gl;pw'
run; eq "regex re: sur le titre" "$(typed)" 'gl<tab>pw<enter>'

reset; win firefox "Accueil"; vault 're:^git(hub|lab)$;gl;pw'
run; eq "regex sans correspondance : rien tapé" "$(typed)" '[Aucune règle pour : Accueil]'

reset; win kitty "Terminal"; vault 'discord;moi;pw'
run; eq "aucune règle : rien tapé" "$(typed)" '[Aucune règle pour : Terminal]'; eq "aucune règle : code 1" "$rc" 1

reset; win discord "x"; vault ';moi;pw
{pass};moi;pw'
run; eq "motif vide ne matche jamais" "$(typed)" '[Aucune règle pour : x]'

reset; win discord "x"; vault 're:(;moi;pw'
run; eq "regex invalide ignorée" "$(typed)" '[Aucune règle pour : x]'

echo "== plusieurs correspondances =="
vault 'discord;compte1;p1
discord;compte2;p2'
reset; win discord "x"; export MENU_CHOICE=2
run; eq "menu : choix 2" "$(typed)" 'compte2<tab>p2<enter>'
has "menu : affiche les identifiants" "$(cat "$T/menu_in")" 'compte1'
hasnt "menu : n'affiche jamais les mots de passe" "$(cat "$T/menu_in")" 'p1'

reset; win discord "x"
run; eq "menu annulé : rien tapé" "$(typed)" ''; eq "menu annulé : code 0" "$rc" 0

reset; win discord "x"; export MENU_CHOICE=1
printf '{"class":"kitty","title":"autre"}\n' >"$T/menu_switch"
run; eq "fenêtre changée pendant le menu : rien tapé" "$(typed)" '[La fenêtre active a changé pendant le choix : rien n'"'"'a été saisi]'

vault 'discord;moi;pw
Discord;moi;pw'
reset; win discord "x"
run; eq "règles identiques : pas de menu" "$(typed)" 'moi<tab>pw<enter>'

echo "== erreurs =="
vault 'discord{user,bidule};moi;pw'
reset; win discord "x"
run; eq "étape inconnue : rien tapé" "$(typed)" '[Séquence invalide : {user,bidule}]'

vault 'discord{};moi;pw'
reset; win discord "x"
run; eq "séquence vide : rien tapé" "$(typed)" '[Séquence invalide : {}]'

vault 'discord;moi;pw'
reset; win discord "x"; touch "$T/pass_fail"
run; has "pass en échec : notification" "$(typed)" '[Coffre illisible'; hasnt "pass en échec : rien tapé" "$(typed)" 'moi'; eq "pass en échec : code 1" "$rc" 1

reset; win discord "x"; touch "$T/wtype_fail"
run; has "wtype en échec : notification" "$(typed)" '[Échec de la saisie (wtype)]'

reset; printf '{}\n' >"$T/win.json"
run; has "aucune fenêtre active : notification" "$(typed)" '[Aucune fenêtre active]'

echo "== wait:N =="
vault 'discord{user,wait:0.1,pass};moi;pw'
reset; win discord "x"
run; eq "wait:0.1" "$(typed)" 'moipw'
vault 'discord{user,wait:abc,pass};moi;pw'
reset; win discord "x"
run; eq "wait:abc invalide" "$(typed)" '[Séquence invalide : {user,wait:abc,pass}]'

echo "== copy =="
vault 'banque{copy};moi;SecretXYZ'
reset; win banque "x"; printf 'ID1\tSecretXYZ\nID2\tautre chose\n' >"$T/hist"
run; eq "copy : rien tapé" "$(typed | tr -d '{}')" 'SENSITIVE[Mot de passe copié, effacé dans 1 s]'
eq "copy : presse-papier = mot de passe" "$(cat "$T/clip")" 'SecretXYZ'
sleep 2.5
[ ! -e "$T/clip" ] && ok "copy : presse-papier effacé après le délai" || ko "copy : presse-papier effacé après le délai"
eq "cliphist : seule l'entrée du mot de passe supprimée" "$(cat "$T/hist")" $'ID2\tautre chose'

reset; win banque "x"; printf 'ID2\tautre chose\n' >"$T/hist"
run; printf 'copié par moi ensuite' | { cat >"$T/clip"; }
sleep 2.5
eq "copy : contenu changé entre-temps = non touché" "$(cat "$T/clip")" 'copié par moi ensuite'
eq "cliphist : autres entrées intactes" "$(cat "$T/hist")" $'ID2\tautre chose'

vault 'banque{pass,copy,enter};moi;SecretXYZ'
reset; win banque "x"
run; has "copy mélangé à la saisie" "$(typed)" 'SecretXYZ'

echo "== --dry-run =="
vault 'discord;moi;MotDePasseSecret'
reset; win discord "x"
run --dry-run; eq "dry-run : rien tapé" "$(typed)" ''; has "dry-run : règle affichée" "$out" 'discord → moi'
hasnt "dry-run : pas de mot de passe" "$out" 'MotDePasseSecret'; has "dry-run : saisie directe" "$out" 'saisie directe'
vault 'discord;a;1
discord;b;2'
run --dry-run; has "dry-run : annonce le menu" "$out" 'menu de choix'

echo "== --check =="
vault 'discord;moi;pw1
Discord;moi;pw1
github{user,pass};gh;pwsecret'
run --check; eq "check : coffre sain code 0" "$rc" 0; has "check : résumé" "$out" '3 règle(s), 0 erreur(s), 0 avertissement(s)'

vault 'ligne sans separateur
{pass};x;mdpvide
re:(;x;mdpregex
site{user,zzz};x;mdpseq
a;x;1
A;y;2'
run --check; eq "check : erreurs code 1" "$rc" 1
has "check : ligne mal formée" "$out" 'ERREUR ligne 1 : ligne mal formée'
has "check : motif vide" "$out" 'ERREUR ligne 2 : motif vide'
has "check : regex invalide" "$out" 'regex invalide'
has "check : séquence invalide" "$out" 'séquence invalide {user,zzz}'
has "check : même motif, autre compte" "$out" 'ATTENTION ligne 6'
hasnt "check : aucun secret affiché" "$out" 'mdp'
hasnt "check : ligne sans séparateur non recopiée" "$out" 'sans separateur'

echo "== --add =="
rm -f "$T/store/autopass/vault.gpg"; : >"$T/vault"; reset; win discord "Discord"
printf '1\nmoi@ex.com\nMonMdp\nMonMdp\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add : coffre créé" "$(cat "$T/vault")" 'discord;moi@ex.com;MonMdp'

vault 'discord;a;b'; reset; win firefox "Sign in to GitHub — Mozilla Firefox"
printf '2\ngh\nx;y\nx;y\nuser,tab,pass\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add : titre court + séquence + ; dans le mot de passe" "$(sed -n 2p "$T/vault")" 'Sign in to GitHub{user,tab,pass};gh;x;y'
eq "add : ancien contenu conservé" "$(sed -n 1p "$T/vault")" 'discord;a;b'

before=$(cat "$T/vault"); reset; win firefox "Sign in to GitHub"
printf '3\nautre\nu\nm1\nm2\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add : mots de passe différents : coffre intact" "$(cat "$T/vault")" "$before"

reset; win discord "x"
printf '1\nmoi\nm\nm\n\nn\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add : doublon refusé : coffre intact" "$(cat "$T/vault")" "$before"

reset; win discord "x"; touch "$T/pass_fail"
printf '1\nmoi\nm\nm\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add : coffre illisible : jamais d'écrasement" "$(cat "$T/vault")" "$before"; hasnt "add : pas d'insert" "$(cat "$T/log")" INSERT

reset; win discord "x"
printf '1\nmoi\nm\nm\nuser,nimporte\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add : séquence invalide : coffre intact" "$(cat "$T/vault")" "$before"

echo
printf '%d ok, %d échec(s)\n' "$pass_n" "$fail_n"
[ "$fail_n" -eq 0 ]
