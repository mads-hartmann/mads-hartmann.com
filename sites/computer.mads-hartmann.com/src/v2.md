---
title: ~ v2
toc: true
---

This is v2. The major change from [v1](/v1) is that I now do 99% of my development in [Cloud Development Environments (CDE)](https://www.gitpod.io/cde) which means that I install _very_ few tools locally.

## Decisions and tl;dr

- I automate as little of the initial setup as possible (installing apps etc.). Spending time automating something that it's quite unlikely I'll ever run again on the same OS, the same hardware, or even the same desired end goal, just wasn't worth the effort for me. Instead I maintain a little setup guide for the few occasions where I actually have to set up a new mac from scratch (see below).

- I manage global system dependencies using Nix. I don't use [homebrew](https://brew.sh).

- I use ZSH as my shell (that's the default since macOS Catalina). I use Spaceship as my prompt configuration.

- I use the default Terminal rather than [iTerm](https://iterm2.com) as I do very little in my local terminal these days.

- I use 1Password

## Setting up a new mac

### Installing GUI apps

- [Raycast](https://raycast.com/) A lovely tool which helps you control your apps and OS. Replaced my usage of Alfred and BetterSnapTool.
- [1Password](https://1password.com) for all my personal credentials. Install it using the App Store.

### Setting up Nix

To install Nix I do need some basic development tools installed like `git`, `curl` and so on:

```sh
xcode-select --install
```

I install Nix using [The Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)

```h
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Shell

Don't show the `Last login` message for every new terminal session:

```sh
touch ~/.hushlogin
```

Install Starship

```sh
nix profile install nixpkgs#starship
```

Create a basic profile for ZSH (`touch ~/.zshrc`) and add the following

```sh
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# Produced by starship init zsh
source <(/Users/mads/.nix-profile/bin/starship init zsh --print-full-init)

autoload -Uz compinit && compinit
```

### SSH

I use 1Password to manage my SSH keys ([docs](https://developer.1password.com/docs/ssh)) and rely on their SSH agent ([docs](https://developer.1password.com/docs/ssh/agent)). For the agent to work the following is placed in `~/.ssh/config`:

```
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

To verify it works run the following

```sh
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
ssh-add -l
```

### devenv

I use [devenv](https://devenv.sh/) where I can:

```sh
nix profile install github:cachix/devenv/v0.6
```

### VSCode

I try to keep my local configuration minimal.

Installed extensions snap-shotted on the 5th of March 2023 

```sh
$ code --list-extensions
bbenoist.Nix
brody715.vscode-cuelang
dbaeumer.vscode-eslint
eamodio.gitlens
EditorConfig.EditorConfig
esbenp.prettier-vscode
gitpod.gitpod-desktop
hashicorp.terraform
liviuschera.noctis
ms-vscode-remote.remote-ssh
ms-vscode-remote.remote-ssh-edit
ms-vscode.remote-explorer
nickgo.cuelang
PKief.material-icon-theme
SimonSiefke.prettier-vscode
streetsidesoftware.code-spell-checker
```

<details>
  <summary>settings.json</summary>
  <pre>
  <code>
{
  "editor.multiCursorModifier": "ctrlCmd",
  "editor.formatOnSave": true,
  "workbench.activityBar.visible": true,
  "workbench.colorTheme": "Noctis Minimus",
  "workbench.startupEditor": "none",
  "window.restoreWindows": "none",
  "window.commandCenter": true,
  "workbench.iconTheme": "material-icon-theme",
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[css]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[scss]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
  </code>
  </pre>
</details>