---
layout: post-no-separate-excerpt
title: "Gitpod CLI Tips & Tricks"
date: 2023-12-19 09:00:00
colors: pinkred
---

Gitpod just released a proper CLI 🥳 You can read more about it in [Take Gitpod to your local command line](https://www.gitpod.io/changelog/gitpod-cli).

I've been testing the CLI for quite a while internally and really love it. I've been having a lot of fun combining [gh](https://cli.github.com), [fzf](https://github.com/junegunn/fzf), and [gitpod](https://www.gitpod.io/docs/references/gitpod-cli) to cover most of my daily workflows.

Here are some of my favorite little scripts form my `~/.zshrc`

## new

<img src="/images/gitpod-cli/new.png" width="100%" />

This allows me to type `new` in my terminal to get an interactive picker with my most commonly used repositories. The real list is longer but I've redacted a few private repositories 😉

```zsh
function new {
  if [[ "${1:-}" == "" ]];
  then
    {
    echo "https://github.com/gitpod-io/gitpod"
    echo "https://github.com/mads-hartmann/gitpod-dotfiles"
    echo "https://github.com/mads-hartmann/mads-hartmann.com"
    } \
    | fzf \
    | xargs -0 gitpod workspace create --open --editor code-desktop
  else
    gitpod workspace create --open --editor code-desktop "$1"
  fi
}
```

## gppr

<img src="/images/gitpod-cli/gppr.png" width="100%" />

Short for Gitpod PR. This uses `gh` to list all my open PRs and then opens a Gitpod workspace from that context. I use this **all** the time as I usually create DRAFT PRs really early and use them to keep track of the work I have in flight.

```zsh
function gppr {
  gh api -X GET search/issues -f q="is:open is:pr author:@me archived:false" --jq '.items[].html_url' \
  | fzf --preview 'gh pr view {}' \
  | xargs -0 gitpod workspace create --open --editor code-desktop
}
```

## gpo

<img src="/images/gitpod-cli/gpo.png" width="100%" />

Short for Gitpod Open. This lists all Gitpod workspaces and provides a quick way to filter and open a specific one. I mostly use this if I stopped a workspace before heading out for launch and I want to start that same workspace rather than create a new one.

```zsh
function gpo {
  gitpod workspace list -r -f id \
  | fzf --preview 'gitpod ws get {}' \
  | tr -d '\n' \
  | xargs -0 gitpod workspace open
}
```

## gpgc

<img src="/images/gitpod-cli/gpgc.png" width="100%" />

Short for Gitpod Garbage Collect. This is a quick way to clean up in my list of workspaces. For this I use the fzf feature of hitting `tab` to select multiple entries.

```zsh
function gpgc {
  gitpod workspace list -f id \
  | fzf -m --preview 'gitpod ws get {}' \
  | xargs -I{} gitpod workspace delete {}
}
```
