---
title: ~
toc: true
---

# ~

I've tried a lot of different approaches to managing the configuration of my computers over the years. They varied in scope and complexity, but they all eded up being too much work to maintain. So this is my final iteration[^1].

## Decisions and tl;dr

- I automate as little of the initial setup as possible (installing apps etc.). Spending time automating something that it's quite unlikely I'll ever run again on the same OS, the same hardware, or even the same desired end goal, just wasn't worth the effort for me. Instead I maintain a little setup guide for the few occasions where I actually have to set up a new mac from scratch (see below).

- I use a [bare git](https://git-scm.com/docs/git-clone#Documentation/git-clone.txt---bare) repository - [mads-hartmann/dotfilesv2](https://github.com/mads-hartmann/dotfilesv2) - in my `$HOME` folder for the actual dotfiles

- I use ZSH as my shell (that's the default since macOS Catalina). I use Spaceship as my prompt configuration.

- I use [asdf] to manage different versions of programming languages.

## Setting up a new mac

### 1Password

I use [1Password](https://1password.com) for all my personal credentials. Install it using the App Store ([direct link](https://apps.apple.com/dk/app/1password-7-password-manager/id1333542190?mt=12))

### XCode command-line tools

Install all the command-line tools like `make`, `git`, etc.

```sh
xcode-select --install
```

### Homebrew & essential tools

Install [homebrew](https://brew.sh) so we can install all the other things we'll need:

```sh
/usr/bin/ruby \
    -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

[iTerm](https://iterm2.com) is my terminal of choice:

```sh
brew install --cask iterm2
```

I use the [Fira Mono for Powerline](https://github.com/powerline/fonts) at the moment:

```sh
brew install svn # Needed for font-fira-mono-for-powerline
brew install homebrew/cask-fonts/font-fira-mono-for-powerline
```

I use [Docker](https://www.docker.com)

```sh
brew install --cask docker
```

I almost always end up needed some of the gnu utilities when writing scripts that should work on Linux (e.g. for CI)

```sh
brew install coreutils
```

I use [cheat](https://github.com/chubin/cheat.sh) and [tldr](https://github.com/tldr-pages/tldr) to look up examples of common use-cases for tools.

```sh
brew install cheat tldr
```

I use [asdf] to manage different language versions and switching between them.

```sh
brew install asdf
```

### Shell

Install [ZSH completions](https://github.com/zsh-users/zsh-completions):

```sh
brew install zsh-completions
sudo chown -R $(whoami) /usr/local/share/zsh/site-functions /usr/local/share /usr/local/share/zsh
sudo chmod -R 755 /usr/local/share/zsh/site-functions /usr/local/share /usr/local/share/zsh
```

Install [starship](http://starship.rs)

```sh
brew install starship
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

### Setting up dotfiles

Based on [this article](https://www.atlassian.com/git/tutorials/dotfiles).

I use a bare git repostiory in my $HOME folder to track my dotfiler, together with a convenience alias for git named `config`.

```sh
# Set up the bare repository
git clone --bare git@github.com:mads-hartmann/dotfilesv2.git
alias config='/usr/bin/git --git-dir=$HOME/dotfilesv2.git/ --work-tree=$HOME'

# Move things to backup directory for review later.
mkdir -p .config-backup && \
config checkout 2>&1 | grep '\t' | awk '{gsub(/\t/,"", $0);print}' | xargs -I{} sh -c 'mkdir -p ".config-backup/$(dirname "{}")" && mv "{}" ".config-backup/{}"'

# Now checkout the dotfiles
config checkout
```

### Programming languages

For the most part I use Docker during development on my own projects, but sometimes it's still handy to have a programming language installed on the system, and sometimes you need to be able to easily switch between versions. Because of that I use [asdf](https://asdf-vm.com) to handle all my programming languages.

#### NodeJS

Install [NodeJS](https://nodejs.org/en/)

```sh
asdf plugin add nodejs

# The NodeJS asdf plugin verifies the binaries
# See https://github.com/asdf-vm/asdf-nodejs for more information
brew install gpg
bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring'

asdf install nodejs 15.8.0
asdf global nodejs 15.8.0
```

#### Python

Install [Python](https://www.python.org)

```sh
asdf plugin add python
asdf install python 3.9.1
asdf global python 3.9.1
```

#### Ruby

Install [Ruby](https://www.ruby-lang.org/en/):

```sh
asdf plugin add ruby
asdf install ruby 3.0.0
asdf global ruby 3.0.0
```

No need to set `GEM_HOME` as it depends on the version of Ruby that's activated. Install global gems:

```sh
gem install bundler
```

Verify everything looks as expected:

```sh
which ruby      # Make sure it is the .asdf/shims one
ruby --version  # ruby 3.0.0
gem env         # It should use the .asdf path for most things
```

#### Terraform

Install [Terraform](https://www.terraform.io)

```sh
asdf plugin add terraform
asdf install terraform 0.14.6
asdf global terraform 0.14.6
```

#### ShellCheck

Install [ShellCheck](https://www.shellcheck.net)

```sh
brew install shellcheck
```

### Visual Studio Code

Sorry Emacs, I've converted:

```sh
brew install --cask visual-studio-code
```

I use the [EditorConfig](https://editorconfig.org) [extension](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig).

```sh
code --install-extension EditorConfig.EditorConfig
```

I use [GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens) as it has a lot of more advanced Git features that are really handy

```sh
code --install-extension eamodio.gitlens
```

I use the [draw.io integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) to be able to edit SVGs using [draw.io](https://draw.io) inside of VSCode; this makes it really easy to embed diagrams in your documentation as SVGs while still being able to edit them - and if you don't use VSCode you can just use [draw.io](https://draw.io) in your browser.

```sh
code --install-extension hediet.vscode-drawio
```

The rest of the configuration lives in my dotfiles, so they should already be in place.

### Other essential apps

- [Raycast](https://raycast.com/) A lovely tool which helps you control your apps and OS. Replaced my usage of Alfred and BetterSnapTool.
- [Things](https://culturedcode.com/things/)
- [TablePlus](https://tableplus.com)

[^1]: Please let this be the final version.

[asdf]: https://asdf-vm.com
