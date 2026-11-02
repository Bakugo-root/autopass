#!/usr/bin/env bash
# autopass tests using fake tools (wtype, pass, hyprctl, wl-copy, cliphist...).
# Touches neither your real vault nor your clipboard. Usage: tests/run.sh
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/store/autopass"
export T

# ---------- fake tools ----------
mock() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }

mock hyprctl 'cat "$T/win.json"'
mock wtype 'if [ "$1" = "-" ]; then echo "TYPE:$(cat)" >>"$T/log"; else echo "KEY:$2" >>"$T/log"; fi
[ ! -e "$T/wtype_fail" ]'
mock pass 'case $1 in
  show) [ -e "$T/pass_fail" ] && exit 1; cat "$T/vault" ;;
  insert) cat >"$T/vault"; echo INSERT >>"$T/log" ;;
  edit) echo "EDIT:$EDITOR:$2" >>"$T/log" ;;
esac'
mock nano 'true'
mock gpgconf '[ ! -e "$T/gpgconf_fail" ] && echo "GPGCONF:$*" >>"$T/log"'
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
ko()   { fail_n=$((fail_n + 1)); printf '  FAIL %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else ko "$1" "expected [$3] got [$2]"; fi; }
has()  { if [[ $2 == *"$3"* ]]; then ok "$1"; else ko "$1" "[$3] not found in [$2]"; fi; }
hasnt(){ if [[ $2 != *"$3"* ]]; then ok "$1"; else ko "$1" "[$3] found in [$2]"; fi; }

win()   { printf '{"class":"%s","title":"%s"}\n' "$1" "$2" >"$T/win.json"; }
vault() { printf '%s\n' "$1" >"$T/vault"; touch "$T/store/autopass/vault.gpg"; }
reset() { : >"$T/log"; rm -f "$T/pass_fail" "$T/menu_switch" "$T/clip" "$T/wtype_fail" "$T/hist" "$T/gpgconf_fail"; unset MENU_CHOICE; }
# readable log: typed text, <tab>, <enter>, [NOTIFY ...]
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

echo "== basic typing =="
reset; win discord "Discord"; vault 'discord;me@ex.com;pw1'
run; eq "default sequence" "$(typed)" 'me@ex.com<tab>pw1<enter>'

reset; vault 'discord{pass,enter};;123456'
run; eq "sequence {pass,enter}, empty username" "$(typed)" '123456<enter>'

reset; vault 'discord{ USER , Tab,pass };me;secret'
run; eq "spaces and case ignored in the sequence" "$(typed)" 'me<tab>secret'

reset; vault 'discord;me;a;b;c'
run; eq "password containing ;" "$(typed)" 'me<tab>a;b;c<enter>'

reset; vault '# comment

discord;me;x'
run; eq "comments and empty lines ignored" "$(typed)" 'me<tab>x<enter>'

echo "== matching =="
reset; win firefox "Sign in to GitHub — Mozilla Firefox"; vault 'sign in to github;gh;pw'
run; eq "title contained, case-insensitive" "$(typed)" 'gh<tab>pw<enter>'

reset; win DISCORD "x"; vault 'discord;me;pw'
run; eq "class equal, case-insensitive" "$(typed)" 'me<tab>pw<enter>'

reset; win firefox "GitLab login"; vault 're:^git(hub|lab)$|gitlab;gl;pw'
run; eq "re: regex on the title" "$(typed)" 'gl<tab>pw<enter>'

reset; win firefox "Home"; vault 're:^git(hub|lab)$;gl;pw'
run; eq "regex without match: nothing typed" "$(typed)" '[No rule for: Home]'

reset; win kitty "Terminal"; vault 'discord;me;pw'
run; eq "no rule: nothing typed" "$(typed)" '[No rule for: Terminal]'; eq "no rule: exit code 1" "$rc" 1

reset; win discord "x"; vault ';me;pw
{pass};me;pw'
run; eq "empty pattern never matches" "$(typed)" '[No rule for: x]'

reset; win discord "x"; vault 're:(;me;pw'
run; eq "invalid regex ignored" "$(typed)" '[No rule for: x]'

echo "== several matches =="
vault 'discord;account1;p1
discord;account2;p2'
reset; win discord "x"; export MENU_CHOICE=2
run; eq "menu: choice 2" "$(typed)" 'account2<tab>p2<enter>'
has "menu: shows usernames" "$(cat "$T/menu_in")" 'account1'
hasnt "menu: never shows passwords" "$(cat "$T/menu_in")" 'p1'

reset; win discord "x"
run; eq "menu cancelled: nothing typed" "$(typed)" ''; eq "menu cancelled: exit code 0" "$rc" 0

reset; win discord "x"; export MENU_CHOICE=1
printf '{"class":"kitty","title":"other"}\n' >"$T/menu_switch"
run; eq "window changed during the menu: nothing typed" "$(typed)" '[The active window changed during the choice: nothing was typed]'

vault 'discord;me;pw
Discord;me;pw'
reset; win discord "x"
run; eq "identical rules: no menu" "$(typed)" 'me<tab>pw<enter>'

echo "== errors =="
vault 'discord{user,gizmo};me;pw'
reset; win discord "x"
run; eq "unknown step: nothing typed" "$(typed)" '[Invalid sequence: {user,gizmo}]'

vault 'discord{};me;pw'
reset; win discord "x"
run; eq "empty sequence: nothing typed" "$(typed)" '[Invalid sequence: {}]'

vault 'discord;me;pw'
reset; win discord "x"; touch "$T/pass_fail"
run; has "pass failing: notification" "$(typed)" '[Vault unreadable'; hasnt "pass failing: nothing typed" "$(typed)" 'me'; eq "pass failing: exit code 1" "$rc" 1

reset; win discord "x"; touch "$T/wtype_fail"
run; has "wtype failing: notification" "$(typed)" '[Typing failed (wtype)]'

reset; printf '{}\n' >"$T/win.json"
run; has "no active window: notification" "$(typed)" '[No active window]'

echo "== wait:N =="
vault 'discord{user,wait:0.1,pass};me;pw'
reset; win discord "x"
run; eq "wait:0.1" "$(typed)" 'mepw'
vault 'discord{user,wait:abc,pass};me;pw'
reset; win discord "x"
run; eq "wait:abc invalid" "$(typed)" '[Invalid sequence: {user,wait:abc,pass}]'

echo "== copy =="
vault 'bank{copy};me;SecretXYZ'
reset; win bank "x"; printf 'ID1\tSecretXYZ\nID2\tother thing\n' >"$T/hist"
run; eq "copy: nothing typed" "$(typed | tr -d '{}')" 'SENSITIVE[Password copied, cleared in 1 s]'
eq "copy: clipboard = password" "$(cat "$T/clip")" 'SecretXYZ'
sleep 2.5
[ ! -e "$T/clip" ] && ok "copy: clipboard cleared after the delay" || ko "copy: clipboard cleared after the delay"
eq "cliphist: only the password entry removed" "$(cat "$T/hist")" $'ID2\tother thing'

reset; win bank "x"; printf 'ID2\tother thing\n' >"$T/hist"
run; printf 'copied by me afterwards' | { cat >"$T/clip"; }
sleep 2.5
eq "copy: content changed meanwhile = untouched" "$(cat "$T/clip")" 'copied by me afterwards'
eq "cliphist: other entries intact" "$(cat "$T/hist")" $'ID2\tother thing'

vault 'bank{pass,copy,enter};me;SecretXYZ'
reset; win bank "x"
run; has "copy mixed with typing" "$(typed)" 'SecretXYZ'

echo "== --dry-run =="
vault 'discord;me;VerySecretPassword'
reset; win discord "x"
run --dry-run; eq "dry-run: nothing typed" "$(typed)" ''; has "dry-run: rule shown" "$out" 'discord → me'
hasnt "dry-run: no password" "$out" 'VerySecretPassword'; has "dry-run: direct typing" "$out" 'direct typing'
vault 'discord;a;1
discord;b;2'
run --dry-run; has "dry-run: announces the menu" "$out" 'choice menu'

echo "== --check =="
vault 'discord;me;pw1
Discord;me;pw1
github{user,pass};gh;pwsecret'
run --check; eq "check: healthy vault exit 0" "$rc" 0; has "check: summary" "$out" '3 rule(s), 0 error(s), 0 warning(s)'

vault 'line without separator
{pass};x;pwempty
re:(;x;pwregex
site{user,zzz};x;pwseq
a;x;1
A;y;2'
run --check; eq "check: errors exit 1" "$rc" 1
has "check: malformed line" "$out" 'ERROR line 1: malformed line'
has "check: empty pattern" "$out" 'ERROR line 2: empty pattern'
has "check: invalid regex" "$out" 'invalid regex'
has "check: invalid sequence" "$out" 'invalid sequence {user,zzz}'
has "check: same pattern, other account" "$out" 'WARNING line 6'
hasnt "check: no secret shown" "$out" 'pw'
hasnt "check: separator-less line not echoed" "$out" 'without separator'

echo "== --add =="
rm -f "$T/store/autopass/vault.gpg"; : >"$T/vault"; reset; win discord "Discord"
printf '1\nme@ex.com\nMyPw\nMyPw\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add: vault created" "$(cat "$T/vault")" 'discord;me@ex.com;MyPw'

vault 'discord;a;b'; reset; win firefox "Sign in to GitHub — Mozilla Firefox"
printf '2\ngh\nx;y\nx;y\nuser,tab,pass\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add: short title + sequence + ; in the password" "$(sed -n 2p "$T/vault")" 'Sign in to GitHub{user,tab,pass};gh;x;y'
eq "add: previous content kept" "$(sed -n 1p "$T/vault")" 'discord;a;b'

before=$(cat "$T/vault"); reset; win firefox "Sign in to GitHub"
printf '3\nother\nu\nm1\nm2\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add: different passwords: vault intact" "$(cat "$T/vault")" "$before"

reset; win discord "x"
printf '1\nme\nm\nm\n\nn\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add: duplicate refused: vault intact" "$(cat "$T/vault")" "$before"

reset; win discord "x"; touch "$T/pass_fail"
printf '1\nme\nm\nm\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add: unreadable vault: never overwritten" "$(cat "$T/vault")" "$before"; hasnt "add: no insert" "$(cat "$T/log")" INSERT

reset; win discord "x"
printf '1\nme\nm\nm\nuser,whatever\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "add: invalid sequence: vault intact" "$(cat "$T/vault")" "$before"

echo "== --add: generated password =="
vault 'discord;a;b'; reset; win firefox "Other"
printf '1\nme\n\n12\n\n' | "$root/autopass" --add >"$T/o" 2>&1
gen=$(sed -n 2p "$T/vault"); gen=${gen#*;me;}
[[ $gen =~ ^[A-Za-z0-9\!@#%^\&*_=+.?-]{12}$ ]] && ok "generated: 12 allowed characters, no ;" || ko "generated: 12 allowed characters, no ;" "[$gen]"
hasnt "generated: never displayed" "$(cat "$T/o")" "$gen"
reset; win firefox "Other2"
printf '1\nme\n\n5\n\n' | "$root/autopass" --add >"$T/o" 2>&1
eq "generated: length 5 refused, vault unchanged" "$(wc -l <"$T/vault")" 2

echo "== --list =="
vault 'discord;me;SecretOne
site{user,pass};gh;SecretTwo
garbage line'
run --list; has "list: rule shown" "$out" 'line 1: discord → me  {user,tab,pass,enter}'
has "list: custom sequence" "$out" 'line 2: site → gh  {user,pass}'
has "list: malformed line flagged" "$out" 'line 3: (malformed line'
hasnt "list: no password" "$out" 'Secret'
hasnt "list: malformed line not echoed" "$out" 'garbage'

echo "== --edit =="
reset; EDITOR=myeditor run --edit; has "edit: uses EDITOR" "$(cat "$T/log")" 'EDIT:myeditor:autopass/vault'
reset; EDITOR= VISUAL= run --edit; has "edit: falls back to an installed editor" "$(cat "$T/log")" 'EDIT:nano:autopass/vault'
has "edit: checks the vault afterwards" "$out" 'rule(s)'

echo "== --remove =="
vault 'discord;a;p1
github;b;p2
gitlab;c;p3'
reset; export MENU_CHOICE=2
printf 'y\n' | "$root/autopass" --remove >"$T/o" 2>&1
eq "remove: only the chosen line removed" "$(cat "$T/vault")" $'discord;a;p1\ngitlab;c;p3'
has "remove: menu shows line numbers" "$(cat "$T/menu_in")" '[line 2]'
hasnt "remove: menu never shows passwords" "$(cat "$T/menu_in")" 'p2'

vault 'discord;a;p1'; reset; export MENU_CHOICE=1
printf 'n\n' | "$root/autopass" --remove >"$T/o" 2>&1
eq "remove: refused at the confirmation" "$(cat "$T/vault")" 'discord;a;p1'

reset; export MENU_CHOICE=1
printf 'y\n' | "$root/autopass" --remove >"$T/o" 2>&1
has "remove: last rule leaves a valid empty vault" "$(cat "$T/vault")" '# autopass vault'
unset MENU_CHOICE

vault 'discord;a;p1

# my note
github;b;p2'
reset; export MENU_CHOICE=1
printf 'y\n' | "$root/autopass" --remove >"$T/o" 2>&1
eq "remove: comments and blank lines preserved" "$(cat "$T/vault")" $'\n# my note\ngithub;b;p2'
unset MENU_CHOICE

echo "== --passwd =="
vault 'discord{pass,enter};a;old;pw
github;b;p2'
reset; export MENU_CHOICE=1
printf 'NewSecret\nNewSecret\n' | "$root/autopass" --passwd >"$T/o" 2>&1
eq "passwd: only the password replaced, pattern/sequence/other lines kept" "$(cat "$T/vault")" $'discord{pass,enter};a;NewSecret\ngithub;b;p2'

vault 'discord;a;old'; reset; export MENU_CHOICE=1
printf 'x1\nx2\n' | "$root/autopass" --passwd >"$T/o" 2>&1
eq "passwd: different passwords: vault intact" "$(cat "$T/vault")" 'discord;a;old'

printf '\n16\n' | "$root/autopass" --passwd >"$T/o" 2>&1
newpw=$(cat "$T/vault"); newpw=${newpw#discord;a;}
[[ ${#newpw} -eq 16 ]] && ok "passwd: generated 16 characters" || ko "passwd: generated 16 characters" "[$newpw]"
unset MENU_CHOICE

vault 'garbage line'; reset; export MENU_CHOICE=1
printf 'a\na\n' | "$root/autopass" --passwd >"$T/o" 2>&1
eq "passwd: malformed line refused" "$(cat "$T/vault")" 'garbage line'
unset MENU_CHOICE

echo "== passphrase asked again =="
G='GPGCONF:--reload gpg-agent'
vault 'discord;a;p1'
reset; run --list;  has "list: flushes the gpg-agent cache" "$(cat "$T/log")" "$G"
reset; EDITOR=myeditor run --edit; has "edit: flushes the gpg-agent cache" "$(cat "$T/log")" "$G"
reset; export MENU_CHOICE=1; printf 'n\n' | "$root/autopass" --remove >"$T/o" 2>&1
has "remove: flushes the gpg-agent cache" "$(cat "$T/log")" "$G"
reset; printf 'a\na\n' | "$root/autopass" --passwd >"$T/o" 2>&1
has "passwd: flushes the gpg-agent cache" "$(cat "$T/log")" "$G"
unset MENU_CHOICE
reset; win firefox "Zzz"; printf '1\nme\nm\nm\n\n' | "$root/autopass" --add >"$T/o" 2>&1
hasnt "add: cache left alone" "$(cat "$T/log")" "GPGCONF"
reset; win discord "x"; run
hasnt "typing by shortcut: cache left alone" "$(cat "$T/log")" "GPGCONF"
reset; run --check; hasnt "check: cache left alone" "$(cat "$T/log")" "GPGCONF"

vault 'discord;a;p1'; reset; touch "$T/gpgconf_fail"
run --list; has "list: refuses when the cache cannot be flushed" "$out" 'Could not flush'; hasnt "list: nothing shown" "$out" 'discord'
reset; touch "$T/gpgconf_fail"; export MENU_CHOICE=1; printf 'y\n' | "$root/autopass" --remove >"$T/o" 2>&1
eq "remove: refuses when the cache cannot be flushed" "$(cat "$T/vault")" 'discord;a;p1'
reset; touch "$T/gpgconf_fail"; EDITOR=myeditor run --edit
hasnt "edit: editor not opened when the cache cannot be flushed" "$(cat "$T/log")" 'EDIT:'
unset MENU_CHOICE

echo
printf '%d ok, %d failure(s)\n' "$pass_n" "$fail_n"
[ "$fail_n" -eq 0 ]
