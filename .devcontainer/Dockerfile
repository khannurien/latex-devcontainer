# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

LABEL org.opencontainers.image.title="LaTeX Dev Container" \
      org.opencontainers.image.description="Full TeX Live + LaTeX Workshop dev container" \
      org.opencontainers.image.source="https://github.com/khannurien/latex-devcontainer" \
      org.opencontainers.image.licenses="MIT"

ARG USERNAME=vscode
ARG TEXLIVE_YEAR=2026
# Point this at a frozen snapshot (e.g. the TUG historic tlnet-final tree for a
# given year) once TEXLIVE_YEAR is no longer the current release.
ARG TEXLIVE_REPO="https://mirror.ctan.org/systems/texlive/tlnet"
# Docs are what `texdoc` reads; sources are almost never needed.
ARG INSTALL_DOCFILES=1
ARG INSTALL_SRCFILES=0

# Runtime dependencies. Note: biber, latexmk, latexindent and chktex all ship
# with scheme-full, so they are deliberately NOT installed from apt -- the apt
# versions routinely disagree with the TeX Live ones (biblatex/biber in
# particular). What apt provides here is what TeX Live cannot: perl itself, the
# perl modules latexindent needs, ghostscript for pdfcrop/ps2pdf/epstopdf, and
# fontconfig so xelatex/lualatex can see system fonts.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    perl \
    wget \
    ca-certificates \
    fontconfig \
    ghostscript \
    make \
    git \
    curl \
    python3 \
    python3-pygments \
    libyaml-tiny-perl \
    libfile-homedir-perl \
    libunicode-linebreak-perl \
    liblog-log4perl-perl \
    liblog-dispatch-perl \
    && rm -rf /var/lib/apt/lists/*

ENV TEXLIVE_INSTALL_PREFIX="/usr/local/texlive"
ENV TEXLIVE_INSTALL_TEXDIR="${TEXLIVE_INSTALL_PREFIX}/${TEXLIVE_YEAR}"

# Install TeX Live as root. instopt_adjustpath symlinks the binaries into
# /usr/local/bin, which keeps the image architecture-agnostic.
RUN set -eux; \
    cd /tmp; \
    # mirror.ctan.org redirects to a *different* random mirror on every request, so
    # resolve it once and take the tarball, its checksum and the packages all from
    # that same host. Retry because individual mirrors have broken TLS or lag sync.
    for attempt in 1 2 3 4 5; do \
      rm -f install-tl-unx.tar.gz install-tl-unx.tar.gz.sha512; \
      resolved="$(curl -fsSL --retry 3 -o install-tl-unx.tar.gz.sha512 \
                  -w '%{url_effective}' "${TEXLIVE_REPO}/install-tl-unx.tar.gz.sha512")" || continue; \
      base="${resolved%/*}"; \
      curl -fsSL --retry 3 -o install-tl-unx.tar.gz "${base}/install-tl-unx.tar.gz" || continue; \
      if sha512sum -c install-tl-unx.tar.gz.sha512; then TL_REPO="${base}"; break; fi; \
      echo "attempt ${attempt}: checksum mismatch from ${base}, retrying"; \
    done; \
    test -n "${TL_REPO:-}"; \
    echo "using mirror: ${TL_REPO}"; \
    tar -xzf install-tl-unx.tar.gz; \
    cd install-tl-*/; \
    { \
      echo "selected_scheme scheme-full"; \
      echo "TEXDIR ${TEXLIVE_INSTALL_TEXDIR}"; \
      echo "TEXMFCONFIG /home/${USERNAME}/.texlive${TEXLIVE_YEAR}/texmf-config"; \
      echo "TEXMFVAR /home/${USERNAME}/.texlive${TEXLIVE_YEAR}/texmf-var"; \
      echo "TEXMFHOME /home/${USERNAME}/texmf"; \
      echo "instopt_adjustpath 1"; \
      echo "tlpdbopt_autobackup 0"; \
      echo "tlpdbopt_install_docfiles ${INSTALL_DOCFILES}"; \
      echo "tlpdbopt_install_srcfiles ${INSTALL_SRCFILES}"; \
    } > texlive.profile; \
    perl ./install-tl --profile=texlive.profile --no-interaction --repository "${TL_REPO}"; \
    cd /tmp; rm -rf install-tl-*; \
    ln -s "$(ls -1 "${TEXLIVE_INSTALL_TEXDIR}/bin" | head -n1)" "${TEXLIVE_INSTALL_TEXDIR}/bin/default"; \
    mkdir -p "/home/${USERNAME}/.texlive${TEXLIVE_YEAR}/texmf-config" \
             "/home/${USERNAME}/.texlive${TEXLIVE_YEAR}/texmf-var" \
             "/home/${USERNAME}/texmf"; \
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.texlive${TEXLIVE_YEAR}" "/home/${USERNAME}/texmf"

# Stable, architecture-independent path to the engines.
ENV PATH="${TEXLIVE_INSTALL_TEXDIR}/bin/default:${PATH}"
ENV TEXMFCONFIG="/home/${USERNAME}/.texlive${TEXLIVE_YEAR}/texmf-config"
ENV TEXMFVAR="/home/${USERNAME}/.texlive${TEXLIVE_YEAR}/texmf-var"
ENV TEXMFHOME="/home/${USERNAME}/texmf"

USER $USERNAME

# Warm the luaotfload font database so the first lualatex run isn't a minutes-long
# font scan, and fail the build early if the toolchain is broken.
RUN set -eux; \
    tlmgr --version; \
    lualatex --version >/dev/null; \
    biber --version >/dev/null; \
    latexmk --version >/dev/null; \
    latexindent --version >/dev/null; \
    luaotfload-tool --update --quiet

WORKDIR /workspace
