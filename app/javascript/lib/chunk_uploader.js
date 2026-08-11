// Streams a File to the chunk endpoint in small sequential requests (each one
// far below the reverse proxy's response timeout), so multi-GB uploads never
// die at ~30s. The server appends the chunks to a per-user scratch file (see
// ChunkedUpload) which the receiving action assembles into Active Storage.
//
// Shared by the admin catalog dropzones (chunked_upload_controller) and the
// member upload form (draft_autosave_controller).
//
// Resolves to { id, filename, contentType } for the form to submit in place of
// the file bytes; rejects when a chunk keeps failing after its retries.
export async function uploadInChunks(file, url, { chunkSize = 8 * 1024 * 1024, retries = 3, onProgress } = {}) {
  const id = uuid()
  const total = Math.max(1, Math.ceil(file.size / chunkSize))

  for (let index = 0; index < total; index++) {
    const chunk = file.slice(index * chunkSize, (index + 1) * chunkSize)
    await sendChunk(url, id, index, chunk, retries)
    if (onProgress) onProgress(Math.round(((index + 1) / total) * 100))
  }

  return { id, filename: file.name, contentType: file.type || "application/octet-stream" }
}

async function sendChunk(url, id, index, chunk, retries) {
  let lastError
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const body = new FormData()
      body.append("upload_id", id)
      body.append("index", index)
      body.append("chunk", chunk)

      const response = await fetch(url, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers: { "X-CSRF-Token": csrfToken() }
      })
      if (!response.ok) throw new Error(`chunk ${index} failed: ${response.status}`)
      return
    } catch (error) {
      lastError = error
    }
  }
  throw lastError
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}

// crypto.randomUUID is available in every browser `allow_browser :modern`
// admits; the fallback keeps a hand-run dev browser from throwing.
function uuid() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID()
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === "x" ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}
