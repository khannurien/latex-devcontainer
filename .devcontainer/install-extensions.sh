#!/usr/bin/env bash
# Install this project's local VS Code extensions into the container's VS Code server.
#
# devcontainer.json has no place for keyboard shortcuts or editor behaviour beyond
# settings: customizations.vscode only understands "settings" and "extensions", and
# keybindings.json is resolved by the VS Code client, not by the server -- so
# dropping a file into ~/.vscode-server/data/User/ does nothing. What *does* travel
# with the container is an extension. So each directory listed below is packaged as
# a .vsix here and installed; edit those directories to change behaviour, this
# script only ships them.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extensions=(
  overleaf-keymap  # Overleaf's keyboard shortcuts
  paste-figure     # Ctrl+V an image -> saved to img/ and wrapped in a figure
)

# The Dev Containers extension installs customizations.vscode.extensions around
# the same time postCreateCommand fires, and both writes touch extensions.json.
# Wait (bounded) for its marker so we don't interleave with it.
marker="$HOME/.vscode-server/data/Machine/.installExtensionsMarker"
for _ in $(seq 1 60); do
  [ -e "$marker" ] && break
  sleep 1
done

# The remote CLI isn't on PATH during postCreateCommand; find the server binary.
code_server="$(ls -1t "$HOME"/.vscode-server/bin/*/bin/code-server 2>/dev/null | head -n1 || true)"
if [ -z "$code_server" ]; then
  echo "install-extensions: no VS Code server found, skipping local extensions." >&2
  exit 0
fi

build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

for name in "${extensions[@]}"; do
  src="${here}/${name}"
  vsix="${build}/${name}.vsix"

  python3 - "$src" "$vsix" <<'PY'
import json, mimetypes, os, sys, zipfile
from xml.sax.saxutils import escape

src, out = sys.argv[1], sys.argv[2]
pkg = json.load(open(f"{src}/package.json"))
ident, version, publisher = pkg["name"], pkg["version"], pkg["publisher"]
kinds = ",".join(pkg.get("extensionKind", ["workspace"]))

manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{ident}" Version="{version}" Publisher="{publisher}" />
    <DisplayName>{escape(pkg["displayName"])}</DisplayName>
    <Description xml:space="preserve">{escape(pkg["description"])}</Description>
    <Tags>{escape(",".join(pkg.get("categories", [])))}</Tags>
    <Categories>{escape(",".join(pkg.get("categories", [])))}</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg["engines"]["vscode"]}" />
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="{kinds}" />
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
"""

# Every file of the extension goes in, so extensions can ship code, not just a manifest.
files = []
for root, _, names in os.walk(src):
    for name in sorted(names):
        path = os.path.join(root, name)
        files.append((path, os.path.relpath(path, src).replace(os.sep, "/")))

defaults = {"json": "application/json", "js": "application/javascript",
            "vsixmanifest": "text/xml", "xml": "text/xml"}
for path, _ in files:
    ext = os.path.splitext(path)[1].lstrip(".").lower()
    if ext and ext not in defaults:
        defaults[ext] = mimetypes.guess_type(path)[0] or "application/octet-stream"

content_types = "\n".join(
    ['<?xml version="1.0" encoding="utf-8"?>',
     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
     *[f'  <Default Extension="{ext}" ContentType="{ctype}" />' for ext, ctype in sorted(defaults.items())],
     '</Types>', ''])

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("extension.vsixmanifest", manifest)
    z.writestr("[Content_Types].xml", content_types)
    for path, rel in files:
        z.write(path, f"extension/{rel}")
PY

  "$code_server" --install-extension "$vsix" --force
done
