#!/usr/bin/env bash
# Install the Overleaf keymap into the container's VS Code server.
#
# devcontainer.json has no place to put keyboard shortcuts: customizations.vscode
# only understands "settings" and "extensions", and keybindings.json is resolved
# by the VS Code client, not by the server -- so dropping a file into
# ~/.vscode-server/data/User/ does nothing. What *does* travel with the container
# is an extension: keybindings contributed by a manifest are registered by the
# workbench. So we package .devcontainer/overleaf-keymap as a .vsix and install
# it. Edit that package.json to change shortcuts; this script just ships it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="${here}/overleaf-keymap"
vsix="$(mktemp -d)/overleaf-keymap.vsix"

python3 - "$src" "$vsix" <<'PY'
import json, sys, zipfile
from xml.sax.saxutils import escape

src, out = sys.argv[1], sys.argv[2]
pkg = json.load(open(f"{src}/package.json"))
ident, version, publisher = pkg["name"], pkg["version"], pkg["publisher"]

manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{ident}" Version="{version}" Publisher="{publisher}" />
    <DisplayName>{escape(pkg["displayName"])}</DisplayName>
    <Description xml:space="preserve">{escape(pkg["description"])}</Description>
    <Tags>keymap</Tags>
    <Categories>Keymaps</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg["engines"]["vscode"]}" />
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace" />
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

content_types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
  <Default Extension="xml" ContentType="text/xml" />
</Types>
"""

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("extension.vsixmanifest", manifest)
    z.writestr("[Content_Types].xml", content_types)
    z.write(f"{src}/package.json", "extension/package.json")
PY

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
  echo "install-keymap: no VS Code server found, skipping Overleaf keymap." >&2
  exit 0
fi

"$code_server" --install-extension "$vsix" --force
rm -rf "$(dirname "$vsix")"
