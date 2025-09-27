uhuh yeah endgame nixos config

# Install
if you're me, you need to bootstrap your secrets for agenix to work right:
```
cp -r /home/sync/.ssh /mnt/home/sync/.ssh
cp /home/sync/Passwords.kdbx /mnt/home/sync/.config/keep
```
if you're not me, you probably have to go in my config and change things for nix to build everything. 

then, proceed with regular installation:
```
sudo nixos-install --root /mnt --flake github:jakeginesin/nix-dots#thonkpad
```
And rebuild with:
```
sudo nixos-rebuild switch --flake.#thonkpad
```

# Some crazy dotfiles
- [Sylk0s](https://github.com/sylk0s/dotfiles)
- [Cajunvoodoo's](https://github.com/Cajunvoodoo/dotfiles)
- [damhiya](https://github.com/damhiya)
- [masterofnull](https://github.com/MasterofNull/nixos)
- [hlissner](https://github.com/hlissner/dotfiles) (also uses bspwm)

# For if you're not me
My setup is designed for (1) [academic research](https://jakegines.in/research) in my PhD, and (2) security research, in my work as a cryptographic auditor. I would highly recommend *not* (not) installing this bare and trying to rawdog figure out my system. Read my system configuration manually and pick out the parts you're interested in. 

Some subtleties about my setup:
- tailscale and syncthing are automatically set up. my note system is integrated with the OS itself with [nf](https://github.com/JakeGinesin/nix-dots/blob/master/home/scripts/journal/nf.sh), alacritty, and rofi. syncing of notes between my server, my phone, and my computer(s) is fully automatic, bootstrapping from the agenix'ed API keys
- my firefox setup is decked out with all my preferred addons, css, and settings [declared](https://github.com/JakeGinesin/nix-dots/blob/master/home/programs/firefox/default.nix). i also have a nice startpage [declared](https://github.com/JakeGinesin/nix-dots/tree/master/home/programs/firefox/startpage)
- i use dnsmasq as opposed to systemd-resolved to manage local dns. I configured nmcli to automatically set dnsmasq to resolve dns queries to [certain websites](https://github.com/JakeGinesin/nix-dots/blob/master/system/networking/blockers.sh) (i.e. instagram.com) to 0.0.0.0 if i'm connected to certain wifi ESSID's (i.e. my university's wifi, "NUWave")
- both neovim+emacs used
- my many helpful [scripts](https://github.com/JakeGinesin/nix-dots/tree/master/home/scripts) are autopackaged using writeScriptBin
- custom font ttfs for polybar are [directly included](https://github.com/JakeGinesin/nix-dots/blob/master/home/fonts/default.nix) in my config because certain icons are no longer supported
- i have a stacked [rebuild script](https://github.com/JakeGinesin/nix-dots/blob/master/home/scripts/rebuild.sh)
- my zsh is [stacked](https://github.com/JakeGinesin/nix-dots/blob/master/home/programs/zsh/default.nix) with many nice [aliases](https://github.com/JakeGinesin/nix-dots/blob/master/home/programs/zsh/zshrc) for automation. secret aliases with hard-coded IPs whatever are stored under an agenix secret
- bspwm on x is used, with sxhkd used for most hotkeys
- papers automatically saved with zotero are [automatically searchable](https://github.com/JakeGinesin/nix-dots/tree/master/home/scripts/document-scripts)
- there is an option for resolution in the [configuration.nix file](https://github.com/JakeGinesin/nix-dots/tree/master/hosts/rq)
