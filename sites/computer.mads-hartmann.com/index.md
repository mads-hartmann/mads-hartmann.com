# Computer

An agent-friendly description of my macOS baseline configuration.

<h2 id="heading-setting-up-a-new-mac">Command-line tools</h2>

Use Apple's command-line tools for Git and the usual build tools. If `xcode-select -p` fails, install them and wait for the installer to finish:

```sh
xcode-select --install
```

<h2 id="heading-homebrew">Homebrew</h2>

Use [Homebrew](https://brew.sh/) for system-wide command-line tools. If it isn't installed, run its [official installer](https://docs.brew.sh/Installation):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the installer's next steps to make `brew` available in the current shell. Other useful tools are `coreutils`, `shellcheck`, and `tldr`; install them when needed.

<h2 id="heading-starship">Starship</h2>

Use [Starship](https://starship.rs/) with its default prompt. Enable it in `~/.zshrc` as shown under Shell.

```sh
brew install starship
```

<h2 id="heading-fzf">fzf</h2>

Use [fzf](https://github.com/junegunn/fzf) for fuzzy history and file search. Enable its Zsh integration as shown under Shell.

```sh
brew install fzf
```

<h2 id="heading-gnu-sed">GNU sed</h2>

Use GNU `sed` in place of the macOS version. The path configuration under Shell makes it the default.

```sh
brew install gnu-sed
```

<h2 id="heading-applications">Applications</h2>

Install desktop apps from their official downloads. I use [Ghostty](https://ghostty.org/) as my terminal. Use [Uses](https://uses.mads-hartmann.com/) for the rest of my apps.

<h2 id="heading-shell">Shell</h2>

Use Zsh with Starship's default prompt, fzf's shell integration, and `~/bin` for personal scripts. GNU `sed` should take precedence over the macOS version.

### `~/.zprofile`

Load Homebrew from its standard Apple Silicon or Intel location, then set up the path:

```zsh
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

typeset -U path
path=("$HOME/bin" "$(brew --prefix)/opt/gnu-sed/libexec/gnubin" $path)
export PATH
```

### `~/.zshrc`

Enable completion, Control-R for history search, and Control-T for file paths.

```zsh
autoload -Uz compinit && compinit
source <(fzf --zsh)
eval "$(starship init zsh)"
```

Create the scripts directory and an empty `~/.hushlogin` to hide the last-login message:

```sh
mkdir -p "$HOME/bin"
touch "$HOME/.hushlogin"
```

<h2 id="heading-git">Git</h2>

Use merge-based pulls, show branches without a pager, and automatically set the upstream on the first push of a new branch.

### `~/.gitconfig`

Merge these settings into the global configuration. Keep my existing `user.name` and `user.email`; on a fresh setup, use `Mads Hartmann` as the name and get the email from me.

```gitconfig
[pull]
    rebase = false
[pager]
    branch = false
[push]
    autoSetupRemote = true
[alias]
    b = branch
    c = commit
    st = status
    s = switch
    co = checkout
    unstage = reset HEAD --
    stats = diff --stat
    mylog = "!git log --author=\"$(git config user.name)\""
    tidy = "!git branch | grep -E -v 'main' | xargs git branch -d"
```

The less obvious aliases:

- `unstage <file>`: remove changes from the index, keeping the working copy.
- `stats`: summarize unstaged changes; add `--cached` for staged changes.
- `mylog`: show commits matching my configured name.
- `tidy`: attempt to delete local branches with `-d`, excluding names containing `main`. Git refuses unmerged or checked-out branches. This is a command for me to run, not a setup step.

<h2 id="heading-ssh">SSH</h2>

I use [1Password to manage my SSH keys](https://www.1password.dev/ssh).

<h2 id="heading-keyboard">Keyboard</h2>

### `~/Library/KeyBindings/DefaultKeyBinding.dict`

Add these shortcuts for apps that use the standard macOS text system:

```text
{
    "~d" = "deleteWordForward:";
    "^w" = "deleteWordBackward:";
    "~f" = "moveWordForward:";
    "~b" = "moveWordBackward:";
}
```

Option-D deletes the next word, Control-W deletes the previous word, and Option-F / Option-B move forward / backward by a word. Relaunch apps after changing the file; editors with their own keybinding systems may handle these shortcuts differently.
