FROM ubuntu:22.04

# Install minimal set of base system requirments
#
# I only want to install what is needed to bootstrap a Nix environment, the rest
# will be installed and controlled by nix.
#
RUN apt update \
    && apt upgrade -y \
    && apt-get install -y \
        # Nix will run a few commands as sudo during installation.
        sudo \
        # Needed to download nix install script, and by nix itself to download binary tarballs
        curl \
        # needed by Nix to unpack binary tarballs
        xz-utils \
        # Gitpod needs git to be availble for the root user.
        #
        # Gitpod will configure user.name, user.email, and credential.helper when starting your workspace
        # but to do so it needs to have the git binary available to invoke `git config --global "key" "value"`
        #
        #   git config --global "user.name" "$GITPOD_GIT_USER_NAME"
        #   git config --global "user.email" "$GITPOD_GIT_USER_EMAIL"
        #   git config --global "credential.helper" "/usr/bin/gp credential-helper"
        #
        git

# Create the Gitpod user
#
# This creates the user that Gitpod would otherwise create for us. We need the user
# in this Dockerfile as we're going to install Nix for the Gtipod user specifically.
#
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    # passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers

# For /home/gitpod/.nix-profile/etc/profile.d/nix.sh to work within
# this Dockerfile both HOME and USER needs to be set.
ENV HOME=/home/gitpod USER=gitpod

WORKDIR $HOME
USER gitpod

# Install nix
#
# I'm using a single-user installation of Nix (hence the --no-daemon).
# While the multi-user installation provides better security, it adds additional
# complexity which wasn't worth the trade-off for my fairly simple usage of nix-shell.
#
RUN curl https://nixos.org/releases/nix/nix-2.11.0/install -o install-nix \
    && chmod +x ./install-nix \
    && ./install-nix --no-daemon \
    && rm ./install-nix \
    # Configure Nix to allow installing unfree packages, meaning packages that use a license
    # that is not considered free.
    && mkdir -p /home/gitpod/.config/nixpkgs \
    && echo '{ allowUnfree = true; }' >> /home/gitpod/.config/nixpkgs/config.nix \
    # Enable support for Flakes
    && mkdir -p /home/gitpod/.config/nix \
    && echo 'experimental-features = nix-command flakes' >> /home/gitpod/.config/nix/nix.conf \
    # Load nix as part for all bash sessions for the Gitpod user
    # This makes nix-shell, nix-env, etc. available
    && echo '. /home/gitpod/.nix-profile/etc/profile.d/nix.sh' >> /home/gitpod/.bashrc
