# 📄 Visual Studio Code Dev Container for LaTeX projects

Full TeX Live 2026 (`scheme-full`) with LaTeX Workshop, `latexmk`, `biber`,
`latexindent` and `chktex` preconfigured.

## Usage

1. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension for Visual Studio Code;
2. Copy the `.devcontainer` directory to your LaTeX project;
3. Open the project in Visual Studio Code;
4. When prompted, reopen the project within the Dev Container;
5. Use the included LaTeX Workshop extension to build the project (see Activity Bar).

Auxiliary files land in `build/`; the final PDF is written next to the source.

## Building the image locally

`devcontainer.json` pulls a prebuilt image from GHCR. To build it yourself,
uncomment the `build` stanza and comment out `image`, or:

```sh
docker build -f .devcontainer/Dockerfile -t latex-devcontainer .
```

Build arguments:

| ARG                | Default                                         | Purpose                                                                         |
| ------------------ | ----------------------------------------------- | ------------------------------------------------------------------------------- |
| `TEXLIVE_YEAR`     | `2026`                                          | TeX Live release; also names the install directory                              |
| `TEXLIVE_REPO`     | `https://mirror.ctan.org/systems/texlive/tlnet` | Package repository                                                              |
| `INSTALL_DOCFILES` | `1`                                             | Set to `0` to drop package documentation (`texdoc`) and roughly halve the image |
| `INSTALL_SRCFILES` | `0`                                             | Package sources                                                                 |
| `USERNAME`         | `vscode`                                        | Non-root user from the base image                                               |

`mirror.ctan.org` always redirects to the *current* TeX Live release. Once 2026
is superseded, pin `TEXLIVE_REPO` to a frozen `tlnet-final` snapshot for that
year to keep rebuilds reproducible.
