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

## Included extensions

Besides LaTeX Workshop, two small extensions live in `.devcontainer/` and are
packaged and installed into the container by `install-extensions.sh` on first
start. Edit their directories to change what they do.

### `overleaf-keymap`

Rebinds VS Code's keyboard shortcuts to Overleaf's:

| Shortcut       | Action                        |
| -------------- | ----------------------------- |
| `Ctrl+B`       | `\textbf{...}` (LaTeX files)   |
| `Ctrl+I`       | `\textit{...}` (LaTeX files)   |
| `Ctrl+Enter`   | Build                         |
| `Ctrl+D`       | Delete line                   |
| `Ctrl+Shift+D` | Duplicate selection           |
| `Ctrl+U`       | Uppercase selection           |
| `Ctrl+Shift+U` | Lowercase selection           |
| `Ctrl+Shift+L` | Go to line                    |
| `Ctrl+G`       | Find next                     |
| `Ctrl+Shift+G` | Find previous                 |
| `F2`           | Toggle fold                   |
| `Alt+Shift+0`  | Unfold all                    |
| `Alt+Shift+1`  | Fold all                      |
| `Alt+Left`     | Start of line                 |
| `Alt+Right`    | End of line                   |
| `Alt+Space`    | Autocomplete                  |

macOS uses `Cmd` where Overleaf does. Shortcuts that only make sense in a `.tex`
file are scoped to LaTeX files, so `Ctrl+B` still toggles the sidebar elsewhere.

### `paste-figure`

`Ctrl+V` an image into a `.tex` file: the image is written to `img/` and the
paste is replaced by a `figure` environment with the caption and label as tab
stops. Two settings, both changeable in `devcontainer.json`:

| Setting                | Default             | Purpose                                   |
| ---------------------- | ------------------- | ----------------------------------------- |
| `pasteFigure.directory`| `img`               | Where the image is saved, relative to root |
| `pasteFigure.template` | `figure` snippet    | Lines inserted at the cursor              |

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
