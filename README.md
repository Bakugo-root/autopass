# autop@ss

Auto-type your username and password on Linux, built on `pass` (GPG).
Keyboard shortcut -> active window -> vault line -> username, Tab, password, Enter (sequence customizable per account).
Nothing runs permanently: the script starts at the shortcut, then exits.

This repository assumes you know how to use `pass` and GPG. If not, start with their documentation (see "Official documentation" at the bottom).

## Why autop@ss

- **Sovereignty**: your passwords stay on your machine, encrypted with your GPG key. No account, no server, no datacenter: there is nobody to trust.
- **Lightweight**: nothing runs in the background. The script starts at the keyboard shortcut, does its job, then exits.
- **One place**: a password changes in the vault and every shortcut picks it up. No more reusing a password to remember it, and no need to read it either: it is never displayed.
- **Works everywhere**: native apps, browsers, any window with a text field. No browser extension to install, so no third-party code reading your pages.
- **Does not touch the clipboard** (unless you choose the optional `copy` step): your copied content is not overwritten, and no clipboard history keeps the password.
- **Discreet**: the password is never displayed on screen, never visible in `ps`, never written in clear text to disk.
- **No homemade cryptography**: all encryption is done by GPG. The script only links the active window to a vault line.
- **Readable and verifiable**: a single bash script, reviewable in a few minutes.
- **Simple vault**: one line per account in a single encrypted file, easy to edit and back up.
- **Offline**: no subscription, no account, no connection needed.
- **Multi-desktop**: Hyprland and KDE Wayland (tested), X11 (untested).

## Supported environments

| Environment | Window detection | Typing | Status |
|---|---|---|---|
| Hyprland (Wayland) | `hyprctl` + `jq` | `wtype` | tested |
| KDE Plasma (Wayland) | `kdotool` | `dotool` | tested |
| X11 (any desktop) | `xdotool` + `xprop` | `xdotool` | untested |

The environment is detected automatically.

## Dependencies
- Always: `git pass gnupg libnotify`
- Hyprland: `wtype jq`
- KDE Wayland: `kdotool` and `dotool` (AUR). The keyboard layout is set with `AUTOPASS_LAYOUT` (`fr` by default).
- X11: `xdotool xorg-xprop`
- Optional:
  - a menu (`fuzzel`, `wofi`, `rofi`, `bemenu` or `tofi`, detected automatically, or `AUTOPASS_MENU="command args"`) to choose when several accounts match;
  - `wl-clipboard` (Wayland) or `xclip` (X11) for the `copy` step.

## Installation

1. Install the tools (Hyprland example)

        sudo pacman -S git pass gnupg libnotify wtype jq

   KDE Wayland example:

        sudo pacman -S git pass gnupg libnotify
        paru -S kdotool dotool

2. Get the code

        git clone https://github.com/Bakugo-root/autopass.git ~/autopass

3. Create your GPG key and initialize the `pass` vault. Everyone has their own key and passphrase:

        gpg --full-generate-key
        pass init YOUR_GPG_ID

   Details (key choice, passphrase, `pass init`) are in the `pass` and GPG documentation linked below.

4. Install the script

        mkdir -p ~/.local/bin
        ln -sf ~/autopass/autopass ~/.local/bin/autopass

   `ln -sf` creates a **symbolic link**: `~/.local/bin/autopass` is not a copy, it is a shortcut to `~/autopass/autopass`.
   - Only one real file: after a `git pull`, the keyboard shortcut immediately uses the new version.
   - `-s` asks for a symbolic link, `-f` replaces the link if it already exists.
   - Check: `ls -l ~/.local/bin/autopass` must show an arrow `->` to `~/autopass/autopass`.
   - If the repository is moved or deleted, the link breaks: run the command again with the new path.
   - To run `autopass` from a terminal (for example `autopass --window`), `~/.local/bin` must be in your `PATH`.
     On "command not found": `fish_add_path ~/.local/bin` in fish, or `export PATH="$HOME/.local/bin:$PATH"` in `~/.bashrc` in bash.
     The keyboard shortcut uses the full path and does not need it.

5. Create the keyboard shortcut. The combination is up to you: `SUPER+P` and `Ctrl+Alt+A` are only examples.
   - Hyprland, in the config (then `hyprctl reload`):

         bind = SUPER, P, exec, ~/.local/bin/autopass

   - KDE: System Settings -> Keyboard -> Shortcuts -> add a command `~/.local/bin/autopass`, with the combination of your choice (for example `Ctrl+Alt+A`).

## The vault

A single encrypted entry, one line per account, in the format `pattern;username;password`:

    env EDITOR=nano pass edit autopass/vault

Examples:

    discord;me@example.com;password1
    Discord;me@example.com;password1
    Sign in to GitHub;my_nickname;password2

- The pattern is compared to the window **class** (equality), otherwise to its **title** (the pattern is contained in it). Case is ignored (`discord` and `Discord` are equivalent).
- A native application has a class (`discord`), a website in Firefox is recognized by its title (`Discord`).
- A pattern starting with `re:` is a **regular expression** tested on the class and on the title: `re:^(GitHub|GitLab)`. Case is ignored here too (`re:^GitHub` also matches `github`). It cannot contain a `;`, and a regex ending with `}` needs an explicit sequence.
- **An uncertain match types nothing.** If several lines match with different accounts, a menu asks which one to use (Esc: nothing is typed). If the window changes during the choice, nothing is typed either. Several lines giving exactly the same account do not trigger a menu. No matching line: "No rule for" notification, nothing is typed.
- Empty lines and lines starting with `#` are ignored.
- The password is everything after the 2nd `;` (it may contain `;`). The pattern and the username must not contain any.

### Typing sequence per account

By default, autopass types: username, Tab, password, Enter. To change that for an account, add the sequence in braces **at the end of the pattern**:

    pattern{step,step,...};username;password

Available steps:

| Step | Effect |
|---|---|
| `user` | types the username |
| `pass` | types the password |
| `tab` | presses Tab |
| `enter` | presses Enter |
| `wait` | pauses for one second (page loading between two steps) |
| `wait:N` | pauses for N seconds, decimals allowed: `wait:2.5` |
| `copy` | copies the password to the clipboard (see below) |

Examples:

    discord;me@example.com;password1                          # default: user,tab,pass,enter
    google{user,enter,wait,pass,enter};me@example.com;pw3     # username and password on two pages
    bank{pass,enter};;123456                                  # password only (empty username)
    site{user,tab,pass};me;pw4                                # fills in without submitting
    app{user,tab,wait:2.5,pass,enter};me;pw5                  # 2.5 s pause in the middle
    stubborn_field{user,copy};me;pw6                          # types the username, copies the password

- Spaces and case are ignored in the sequence (`{ pass , ENTER }` works).
- The sequence is checked **before** typing: an unknown step or an empty sequence gives an "Invalid sequence" notification and nothing is typed.
- Braces are not used for matching: only what comes before the last `{` is the pattern.
- A pattern that itself ends with `}` must get an explicit sequence, for example `Title {special}{user,tab,pass,enter}`.

### The `copy` step: password in the clipboard

For fields where auto-typing fails. The password is copied (with the "sensitive" hint on Wayland), then **cleared after 30 s** (`AUTOPASS_CLEAR_DELAY`, in seconds).
- Only the line copied by autopass is cleared: if you copied something else in the meantime, the clipboard is left alone.
- If `cliphist` is installed, the entry matching this password is removed from it, and only that one.
- A background process therefore stays alive until the clear (30 s), only when `copy` is used.
- On X11 (`xclip`): untested.

## Commands

| Command | Effect |
|---|---|
| `autopass` | types the account of the active window (via the keyboard shortcut) |
| `autopass --add` | adds an account to the vault from a terminal: click on the window within 3 s (`AUTOPASS_ADD_DELAY`), then choose the pattern (class, short title or free), the username, the password (typed without echo and confirmed, or **left empty to generate a random one**, never displayed) and an optional sequence. The existing vault is never overwritten if it could not be read |
| `autopass --list` | lists the rules (line number, pattern, username, sequence). Never prints a password |
| `autopass --edit` | opens the vault in your editor (`$EDITOR`, else `$VISUAL`, else the first of `nano vim nvim vi micro` found), then runs `--check` on the result |
| `autopass --remove` | removes a rule chosen in the menu, after a `[y/N]` confirmation. Other lines, comments and blank lines are kept |
| `autopass --passwd` | changes the password of a rule chosen in the menu (typed twice, or left empty to generate one). The pattern, sequence and username are kept |
| `autopass --check` | validates the whole vault (malformed lines, empty patterns, invalid regexes and sequences, duplicate patterns with different accounts). Never prints a password |
| `autopass --dry-run` | shows which rules match the active window and what would happen (direct typing or menu), without typing anything. Run it from a terminal, then click on the window within 3 s (`AUTOPASS_DRY_DELAY`) |
| `autopass --window` | prints the class and title of the active window. Run it from a terminal, then click on the window within 3 s (`AUTOPASS_WINDOW_DELAY`) |

`--list`, `--edit`, `--remove` and `--passwd` **ask for the GPG passphrase again** every time, even if it is cached (autopass flushes the `gpg-agent` cache with `gpgconf --reload gpg-agent` first, and refuses to continue if it cannot). Someone sitting at your unlocked session cannot read or change your accounts with them. The side effect: the next keyboard-shortcut use asks for the passphrase again too. `--add`, `--check`, `--dry-run` and the keyboard shortcut itself use the cache as usual.

Generated passwords use letters, digits and `!@#%^&*_=+.?-` (never `;`), 8 to 128 characters (20 by default), taken from `/dev/urandom`.

`--remove` and `--passwd` need a menu (see Dependencies) and a terminal for the confirmation and the password prompts.

Errors (unreadable vault, cancelled passphrase, missing tool, failed typing) give a notification and a message on stderr.

## Tests

`tests/run.sh` runs the tests with fake tools (`wtype`, `pass`, `wl-copy`, `cliphist`...): it touches neither the real vault nor the clipboard.

## Testing each piece

Before using the shortcut, test window detection and typing separately.

**1. Active window**: run the command, then click on the wanted window during the 3 seconds.

    autopass --window

Must print the class, then the title of the window. It is also the command that gives the pattern to put in the vault.

**2. Typing alone**: click in a text field during the 3 seconds. The text must come out exact.

Hyprland:

    sleep 3; printf '%s' 'me@example.com' | wtype -

KDE Wayland:

    sleep 3; printf 'type me@example.com\n' | DOTOOL_XKB_LAYOUT=fr dotool

X11:

    sleep 3; printf '%s' 'me@example.com' | xdotool type --file -

- Check `@`, digits and letters that change between keyboard layouts.
- Also test in an Electron app (Discord, VS Code), which is more sensitive to fast typing.
- If characters are wrong on KDE, set `DOTOOL_XKB_LAYOUT` (for example `fr`) and possibly `DOTOOL_XKB_VARIANT`.

## Usage
Click in the username field, then run the shortcut. The GPG passphrase is asked the first time.

## GPG key backup
Without the private key and its passphrase, the vault is unrecoverable (reinstall, dead disk).
Back it up once, off the PC, and never put it in a git repository. The procedure is in the GPG documentation linked below.

## Troubleshooting
- **"No rule for: ..." notification**: no pattern matches the class or the title. Run `autopass --window` again, or add the rule with `autopass --add`.
- **The vault does not behave as expected**: `autopass --check` flags faulty lines, `autopass --dry-run` shows what matches.
- **Characters that appear then disappear** (Electron apps like Discord): on Hyprland, the script therefore types the text character by character with `wtype`.
- **Wrong characters**: do not use `ydotool`, which sends QWERTY key codes and gives a wrong result on an AZERTY keyboard.
- **Nothing happens on Hyprland**: check that the bind is loaded (`hyprctl binds | grep autopass`).
- **`dotool` or `ydotool` types nothing, or permission error**: see [docs/troubleshooting.md](docs/troubleshooting.md) (access to `/dev/uinput`).

## Limits and security
- No anti-phishing protection: any page whose title contains the pattern triggers typing (like KeePass Auto-Type).
- Each press decrypts the whole vault in memory and parses it into shell variables for the duration of the run (about a second). The raw decrypted text is cleared right after parsing, but the parsed passwords of all accounts stay in the script's memory until autopass exits. Nothing is written to disk in clear text.
- The password goes through the typing tools' standard input, so it never appears in `ps`, and it is never written to disk in clear text.
- No TOTP / two-factor authentication: the code is typed by hand.
- The repository contains no secret: the vault lives in `~/.password-store`, outside the repo.

## Official documentation
- `pass`: <https://www.passwordstore.org/> and <https://wiki.archlinux.org/title/Pass>
- GPG: <https://wiki.archlinux.org/title/GnuPG>
- AUR (installing `kdotool`, `dotool`): <https://wiki.archlinux.org/title/AUR>
- `wtype`: <https://github.com/atx/wtype>
- `kdotool`: <https://github.com/jinliu/kdotool>
- `dotool`: <https://git.sr.ht/~geb/dotool>
- `xdotool`: <https://github.com/jordansissel/xdotool>
- `jq`: <https://jqlang.github.io/jq/>
- Hyprland: <https://wiki.hyprland.org/>
