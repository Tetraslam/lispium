# Lispium AUR Package

This directory contains the files needed to publish Lispium to the Arch User Repository (AUR).

## Publishing to AUR

1. Create an AUR account at https://aur.archlinux.org/
2. Set up SSH keys for AUR: https://wiki.archlinux.org/title/AUR_submission_guidelines#Authentication
3. Clone the AUR repository:
   ```bash
   git clone ssh://aur@aur.archlinux.org/lispium-bin.git
   ```
4. Copy PKGBUILD and .SRCINFO to the cloned repo
5. Update the sha256sums with actual checksums from the release
6. Commit and push:
   ```bash
   git add PKGBUILD .SRCINFO
   git commit -m "Initial package lispium-bin 0.1.0"
   git push
   ```

## Updating the Package

1. Update `pkgver` in PKGBUILD
2. Update the sha256sums
3. Regenerate .SRCINFO: `makepkg --printsrcinfo > .SRCINFO`
4. Commit and push

## Testing Locally

```bash
makepkg -si
```

## Installation (for users)

```bash
# Using yay
yay -S lispium-bin

# Using paru
paru -S lispium-bin

# Manual
git clone https://aur.archlinux.org/lispium-bin.git
cd lispium-bin
makepkg -si
```
