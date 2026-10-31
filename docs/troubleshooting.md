# Troubleshooting: access to /dev/uinput

This only affects typing tools that go through `/dev/uinput`:
`dotool` (KDE Wayland) and `ydotool`. On Hyprland with `wtype` or on X11 with `xdotool`, there is nothing to do here.

## Symptoms
- `dotool` or `ydotool` types nothing, or prints a permission error
- `ydotoold` exits immediately (`status=2`) or the socket `/run/user/UID/.ydotool_socket` does not exist

## Diagnosis

    ls -l /dev/uinput
    getfacl /dev/uinput

By default, `/dev/uinput` belongs to `root` and your user has no access.
The `getfacl` output must contain a `user:YOUR_USER:rw-` line. If it is missing, apply the rule below.

## Fix

    echo 'KERNEL=="uinput", MODE="0660", GROUP="input", TAG+="uaccess", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/70-uinput.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=uinput
    getfacl /dev/uinput

- The rule gives the logged-in user access to `/dev/uinput` (`uaccess` tag) without adding them to the `input` group.
  That group can read every keystroke on the machine, which you want to avoid for a password manager.
- **The file number matters**: it must be lower than 73. With an `80-...` name, the `uaccess` tag is applied too late and has no effect
  (the group changes but the `user:...` line does not appear).
- After the fix, `getfacl` must show `user:YOUR_USER:rw-`.
- If access is still denied, log out and log back in.

## Undo the fix

    sudo rm -f /etc/udev/rules.d/70-uinput.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=uinput

`/dev/uinput` goes back to its original permissions.
