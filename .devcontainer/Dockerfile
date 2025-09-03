FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install dependencies for TeX Live installation and usage
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    perl \
    biber \
    wget \
    fontconfig \
    make \
    git \
    curl \
    python3 \
    python3-pygments \
    && rm -rf /var/lib/apt/lists/*

# Set non-root user provided by Microsoft base image
ARG USERNAME=vscode

# Switch to user home directory
USER $USERNAME
WORKDIR /home/$USERNAME

# Set TeX Live paths and update environment
ENV TEXLIVE_INSTALL_PREFIX="/usr/local/texlive"
ENV TEXLIVE_INSTALL_TEXDIR="${TEXLIVE_INSTALL_PREFIX}/2025"
ENV PATH="${TEXLIVE_INSTALL_TEXDIR}/bin/x86_64-linux:${PATH}"

# Download and install TeX Live 2025 as root
RUN wget -q https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar -xzf install-tl-unx.tar.gz && \
    rm install-tl-unx.tar.gz && \
    cd install-tl-* && \
    echo "selected_scheme scheme-full" > texlive.profile && \
    echo "TEXDIR ${TEXLIVE_INSTALL_TEXDIR}" >> texlive.profile && \
    echo "TEXMFCONFIG /home/vscode/.texlive2025/texmf-config" >> texlive.profile && \
    echo "TEXMFVAR /home/vscode/.texlive2025/texmf-var" >> texlive.profile && \
    echo "instopt_adjustpath 1" >> texlive.profile && \
    echo "tlpdbopt_autobackup 0" >> texlive.profile && \
    sudo perl ./install-tl --profile=texlive.profile --no-interaction && \
    cd .. && rm -rf install-tl-*

# User-writeable directories for TeX Live and LuaLaTeX
ENV TEXMFCONFIG="/home/vscode/.texlive2025/texmf-config"
ENV TEXMFVAR="/home/vscode/.texlive2025/texmf-var"
ENV LUAOTFLOAD_HOME="/home/vscode/.texlive2025/texmf-var/luatex-cache"
ENV LUAOTFLOAD_DB="/home/vscode/.texlive2025/texmf-var/luatex-cache/database.sqlite"

# Install latexmk
RUN sudo tlmgr option autobackup 0 && \
    sudo tlmgr install latexmk && \
    sudo tlmgr path add

# Set the working directory back to a neutral location
WORKDIR /workspace
