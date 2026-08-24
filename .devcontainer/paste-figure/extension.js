// Overleaf-style image paste for LaTeX: Ctrl+V an image into a .tex file and it
// is written into the project and replaced by a \begin{figure} block.
//
// This has to be a paste *provider* rather than one of the usual "paste image"
// extensions (mushan.vscode-paste-image and friends): those shell out to
// xclip/pbpaste/powershell on whichever machine runs the extension host, which
// for a dev container is the container -- where there is no clipboard. VS Code
// serialises the clipboard payload from the client to the provider instead, so
// DataTransferItem.asFile() gives us the bytes the user copied on their desktop.

const vscode = require('vscode')
const path = require('path')

const LANGUAGES = ['latex', 'latex-expl3', 'rsweave', 'doctex']

// What \includegraphics can actually consume, for payloads that carry a filename.
const IMAGE_EXTENSIONS = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.tif', '.tiff', '.svg', '.pdf', '.eps'
])

// Clipboard bitmaps arrive with a mime type and a placeholder name, so the
// extension has to come from the mime instead.
const IMAGE_MIMES = new Map([
  ['image/png', '.png'],
  ['image/jpeg', '.jpg'],
  ['image/jpg', '.jpg'],
  ['image/gif', '.gif'],
  ['image/webp', '.webp'],
  ['image/bmp', '.bmp'],
  ['image/tiff', '.tif'],
  ['image/svg+xml', '.svg'],
  ['application/pdf', '.pdf']
])

// 'files' matches any DataTransferItem backed by a file (drag & drop, or a copy
// from the OS file manager); the explicit mimes cover clipboard bitmaps.
const MIME_HINTS = ['files', ...IMAGE_MIMES.keys()]

// Names the OS invents for a clipboard bitmap; not worth keeping.
const GENERIC_NAMES = new Set(['', 'image', 'images', 'clipboard', 'unnamed', 'untitled', 'download'])

function settings(document) {
  return vscode.workspace.getConfiguration('pasteFigure', document)
}

/** First image-ish file in the payload, or undefined -- in which case we let VS Code paste normally. */
function findImage(dataTransfer) {
  const candidates = []
  dataTransfer.forEach((item, mime) => {
    const file = item.asFile()
    if (!file) {
      return
    }
    const named = path.extname(file.name || '').toLowerCase()
    if (IMAGE_EXTENSIONS.has(named)) {
      candidates.push({ file, ext: named })
      return
    }
    const byMime = IMAGE_MIMES.get(mime.toLowerCase().split(';')[0].trim())
    if (byMime) {
      candidates.push({ file, ext: byMime })
    }
  })
  return candidates[0]
}

function timestamp() {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
}

/** A filename LaTeX will not choke on: no spaces, no accents, no braces. */
function baseName(file) {
  const raw = path.basename(file.name || '', path.extname(file.name || ''))
  const slug = raw
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '') // drop the accents NFKD just split off
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
  return GENERIC_NAMES.has(slug) ? `pasted-${timestamp()}` : slug
}

/**
 * Where images live and what \includegraphics paths are relative to. Both are the
 * workspace folder when there is one -- latexmk runs from there, and the existing
 * slides use workspace-relative paths like img/logos.png.
 */
function locate(document) {
  const folder = vscode.workspace.getWorkspaceFolder(document.uri)
  const root = folder ? folder.uri : vscode.Uri.joinPath(document.uri, '..')
  const relative = settings(document).get('directory') || 'img'
  return { root, directory: vscode.Uri.joinPath(root, ...relative.split('/').filter(Boolean)) }
}

async function freeUri(directory, base, ext) {
  for (let i = 0; i < 1000; i++) {
    const uri = vscode.Uri.joinPath(directory, i === 0 ? `${base}${ext}` : `${base}-${i}${ext}`)
    try {
      await vscode.workspace.fs.stat(uri)
    } catch {
      return uri
    }
  }
  throw new Error(`too many files named ${base}${ext} in ${directory.fsPath}`)
}

/** Save the image next to the document and return the figure snippet to insert. */
async function insertFigure(document, dataTransfer, token) {
  const image = findImage(dataTransfer)
  if (!image) {
    return undefined
  }

  const data = await image.file.data()
  if (token.isCancellationRequested || data.length === 0) {
    return undefined
  }

  const { root, directory } = locate(document)
  await vscode.workspace.fs.createDirectory(directory)
  const target = await freeUri(directory, baseName(image.file), image.ext)
  await vscode.workspace.fs.writeFile(target, data)

  const relative = path.relative(root.fsPath, target.fsPath).split(path.sep).join('/')
  const template = settings(document).get('template')
  const body = Array.isArray(template) ? template.join('\n') : String(template)
  // $ and \ are snippet syntax; the path is slugified but the directory may not be.
  return new vscode.SnippetString(body.replace(/\$IMAGE/g, relative.replace(/[$\\}]/g, '\\$&')))
}

/** Failures must not swallow the paste: report, then fall back to a normal paste. */
async function trySnippet(document, dataTransfer, token) {
  try {
    return await insertFigure(document, dataTransfer, token)
  } catch (err) {
    vscode.window.showErrorMessage(`Could not insert the pasted image: ${err instanceof Error ? err.message : String(err)}`)
    return undefined
  }
}

function activate(context) {
  const selector = LANGUAGES.map(language => ({ language, scheme: 'file' }))
  const kind = vscode.DocumentPasteEditKind?.Empty?.append('latex', 'figure')

  context.subscriptions.push(vscode.languages.registerDocumentPasteEditProvider(selector, {
    async provideDocumentPasteEdits(document, _ranges, dataTransfer, _context, token) {
      const snippet = await trySnippet(document, dataTransfer, token)
      return snippet ? [new vscode.DocumentPasteEdit(snippet, 'Insert figure', kind)] : undefined
    }
  }, { providedPasteEditKinds: kind ? [kind] : [], pasteMimeTypes: MIME_HINTS }))

  // Same handling for images dragged into the editor.
  context.subscriptions.push(vscode.languages.registerDocumentDropEditProvider(selector, {
    async provideDocumentDropEdits(document, _position, dataTransfer, token) {
      const snippet = await trySnippet(document, dataTransfer, token)
      return snippet ? new vscode.DocumentDropEdit(snippet, 'Insert figure', kind) : undefined
    }
  }, { providedDropEditKinds: kind ? [kind] : [], dropMimeTypes: MIME_HINTS }))
}

module.exports = { activate, deactivate() {} }
