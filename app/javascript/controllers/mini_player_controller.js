import { Controller } from "@hotwired/stimulus"

// Persistent mini-player host (feature 010). Rendered ONCE in the layout,
// outside #page-content, so the single <video> survives every in-app navigation
// and keeps playing (Constitution V). Two states: EXPANDED (overlays the player
// page's #player-stage) and DOCKED (small, bottom-right). It never auto-pauses
// on lifecycle/visibility/lock — pause only from a control or Media Session.
//
// Driven by `mini-player:load` / `mini-player:dock` events dispatched on
// `document` by the page's `player-source` controller and by autoplay advances.
const CHAIN_KEY = "miniPlayerChain"       // session-scoped autoplay chain (slugs)
const ADVANCE_KEY = "miniPlayerAutoAdvance" // set right before an autoplay Turbo.visit

export default class extends Controller {
  static targets = [
    "video", "controls", "prevBtn", "nextBtn", "captions",
    "timeline", "timelineFill", "currentTime", "duration"
  ]
  static values = { autoplay: Boolean }
  static PROGRESS_INTERVAL = 10

  connect() {
    this.currentSlug = null
    this.dismissed = false
    this.expanded = false
    this.mediaReady = false
    this.viewRecorded = false
    this.lastSavedAt = 0
    this.hideTimer = null

    this.onLoad = this.onLoad.bind(this)
    this.onDockEvent = this.onDockEvent.bind(this)
    this.onPlay = this.onPlay.bind(this)
    this.onPause = this.onPause.bind(this)
    this.onEnded = this.onEnded.bind(this)
    this.onTimeUpdate = this.onTimeUpdate.bind(this)
    this.onLoadedMetadata = this.onLoadedMetadata.bind(this)
    this.onKey = this.onKey.bind(this)
    this.onResize = this.onResize.bind(this)
    this.setAutoplay = this.setAutoplay.bind(this)
    this.onBeforeRender = this.onBeforeRender.bind(this)
    this.onRender = this.onRender.bind(this)
    this.onFullscreenChange = this.onFullscreenChange.bind(this)

    this.onSubtitlesToggle = this.onSubtitlesToggle.bind(this)
    this.onSubtitlesStyle = this.onSubtitlesStyle.bind(this)
    this.onSubtitlesLanguage = this.onSubtitlesLanguage.bind(this)

    document.addEventListener("mini-player:load", this.onLoad)
    document.addEventListener("mini-player:dock", this.onDockEvent)
    document.addEventListener("mini-player:set-autoplay", this.setAutoplay)
    document.addEventListener("mini-player:subtitles-toggle", this.onSubtitlesToggle)
    document.addEventListener("mini-player:subtitles-style", this.onSubtitlesStyle)
    document.addEventListener("mini-player:subtitles-language", this.onSubtitlesLanguage)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("fullscreenchange", this.onFullscreenChange)
    document.addEventListener("webkitfullscreenchange", this.onFullscreenChange)
    window.addEventListener("resize", this.onResize)
    // Turbo moves this permanent element into the new <body> on every Drive
    // visit, which pauses the <video> (browsers pause media on reparent). Capture
    // the play state before the swap and resume it after so playback never stops
    // on navigation (Constitution V).
    document.addEventListener("turbo:before-render", this.onBeforeRender)
    document.addEventListener("turbo:render", this.onRender)
    document.addEventListener("turbo:load", this.onRender)

    const v = this.videoTarget
    v.addEventListener("play", this.onPlay)
    v.addEventListener("pause", this.onPause)
    v.addEventListener("ended", this.onEnded)
    v.addEventListener("timeupdate", this.onTimeUpdate)
    v.addEventListener("loadedmetadata", this.onLoadedMetadata)

    // Announce readiness so a player-source that connected first (full/direct
    // page load) re-dispatches its descriptor and isn't a missed handshake.
    document.dispatchEvent(new CustomEvent("mini-player:connected"))
  }

  disconnect() {
    document.removeEventListener("mini-player:load", this.onLoad)
    document.removeEventListener("mini-player:dock", this.onDockEvent)
    document.removeEventListener("mini-player:set-autoplay", this.setAutoplay)
    document.removeEventListener("mini-player:subtitles-toggle", this.onSubtitlesToggle)
    document.removeEventListener("mini-player:subtitles-style", this.onSubtitlesStyle)
    document.removeEventListener("mini-player:subtitles-language", this.onSubtitlesLanguage)
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("fullscreenchange", this.onFullscreenChange)
    document.removeEventListener("webkitfullscreenchange", this.onFullscreenChange)
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("turbo:before-render", this.onBeforeRender)
    document.removeEventListener("turbo:render", this.onRender)
    document.removeEventListener("turbo:load", this.onRender)
    clearTimeout(this.hideTimer)
  }

  // --- descriptor hand-off ---------------------------------------------------

  // detail: { slug, src, artwork, title, album, prevUrl, nextUrl, resume, list,
  //           viewsUrl, progressUrl, upNextUrl, expanded, viaAutoplay }
  onLoad(event) {
    const d = event.detail || {}
    if (!d.src) return

    const sameVideo = d.slug && d.slug === this.currentSlug && this.videoTarget.src
    if (sameVideo) {
      // Returning to the current video's player page — don't reload, just expand.
      this.desc = { ...this.desc, ...d }
      d.expanded ? this.expand() : this.dock()
      return
    }

    // A new video takes over (single-player invariant).
    this.desc = d
    this.currentSlug = d.slug
    this.dismissed = false
    this.mediaReady = false
    this.viewRecorded = false
    this.lastSavedAt = 0
    this.resume = Number(d.resume) || 0

    this.element.hidden = false
    // Persist the slug on the DOM: the permanent element reconnects on each Turbo
    // Drive visit (resetting instance state), but dataset survives — so the docked
    // tile can still open the right video.
    this.element.dataset.slug = d.slug
    this.videoTarget.src = d.src
    this.videoTarget.poster = d.artwork || ""
    this.syncNeighbors()
    this.loadSubtitles(d)

    // Autoplay chain bookkeeping (session-scoped, survives Turbo navigation).
    if (d.viaAutoplay || sessionStorage.getItem(ADVANCE_KEY)) {
      sessionStorage.removeItem(ADVANCE_KEY)
      this.pushChain(d.slug)
    } else {
      this.setChain([d.slug]) // manual choice reseeds the chain
    }

    d.expanded ? this.expand() : this.dock()
    const p = this.videoTarget.play()
    if (p && p.catch) p.catch(() => {})
  }

  onDockEvent() { if (!this.element.hidden && !this.dismissed) this.dock() }

  // Remember whether we were playing right before Turbo swaps the <body>.
  onBeforeRender() {
    this.resumeAfterRender = !this.element.hidden && !this.dismissed && !this.videoTarget.paused
  }

  // After the swap (which reparents this element and pauses the media), resume.
  onRender() {
    if (this.resumeAfterRender && this.videoTarget.paused) {
      const p = this.videoTarget.play()
      if (p && p.catch) p.catch(() => {})
    }
    if (this.expanded) this.positionExpanded()
  }

  // --- state: expanded (player page) vs docked (everywhere else) -------------

  expand() {
    this.expanded = true
    this.element.classList.add("mini-player--expanded")
    this.element.classList.remove("mini-player--docked", "is-controls")
    this.positionExpanded()
    this.activity()
  }

  dock() {
    this.expanded = false
    const el = this.element
    el.classList.remove("mini-player--expanded", "is-active")
    el.classList.add("mini-player--docked")
    el.style.top = el.style.left = el.style.width = el.style.height = ""
  }

  positionExpanded() {
    const stage = document.getElementById("player-stage")
    if (!stage) return this.dock()
    // Position over the stage in DOCUMENT coordinates. Combined with
    // position:absolute (see CSS), the expanded player scrolls with the page
    // instead of staying pinned to the viewport.
    const r = stage.getBoundingClientRect()
    const el = this.element
    el.style.top = `${r.top + window.scrollY}px`
    el.style.left = `${r.left + window.scrollX}px`
    el.style.width = `${r.width}px`
    el.style.height = `${(r.width * 9) / 16}px`
  }

  onResize() { if (this.expanded) this.positionExpanded() }

  syncNeighbors() {
    if (this.hasPrevBtnTarget) this.prevBtnTarget.hidden = !this.desc.prevUrl
    if (this.hasNextBtnTarget) this.nextBtnTarget.hidden = !this.desc.nextUrl
  }

  // --- subtitles (feature 012) -----------------------------------------------
  // Tracks render through a CSS overlay driven by the active <track>'s cues (the
  // track is in "hidden" mode). Toggling/styling/language changes never touch
  // video.src, so playback is never interrupted (Constitution V).

  loadSubtitles(d) {
    this.tracks = Array.isArray(d.subtitles) ? d.subtitles : []
    this.subEnabled = !!d.subEnabled
    this.activeTrackId = null
    this.applyCaptionStyle({
      textColor: d.subTextColor, background: d.subBgColor,
      fontSize: d.subFontSize, fontWeight: d.subFontWeight
    })
    this.rebuildTracks()
  }

  rebuildTracks() {
    const v = this.videoTarget
    v.querySelectorAll("track").forEach((t) => t.remove())
    if (this.activeTT && this.cueHandler) this.activeTT.removeEventListener("cuechange", this.cueHandler)
    this.activeTT = null
    this.renderCue("")

    if (!this.tracks.length) { this.updateCaptionsVisibility(); return }
    this.tracks.forEach((t) => {
      const el = document.createElement("track")
      el.kind = "subtitles"; el.src = t.vttUrl; el.srclang = t.language
      el.label = t.label; el.dataset.trackId = t.id
      v.appendChild(el)
    })
    const selected = this.tracks.find((t) => t.default) || this.tracks[0]
    this.selectTrack(selected.id)
  }

  selectTrack(trackId) {
    const v = this.videoTarget
    this.activeTrackId = trackId
    const els = Array.from(v.querySelectorAll("track"))
    els.forEach((el, i) => {
      const tt = v.textTracks[i]
      if (!tt) return
      if (el.dataset.trackId === trackId) {
        tt.mode = "hidden"
        if (this.activeTT && this.cueHandler) this.activeTT.removeEventListener("cuechange", this.cueHandler)
        this.cueHandler = () => this.renderActiveCue(tt)
        tt.addEventListener("cuechange", this.cueHandler)
        this.activeTT = tt
        this.renderActiveCue(tt)
      } else {
        tt.mode = "disabled"
      }
    })
    this.updateCaptionsVisibility()
  }

  renderActiveCue(tt) {
    const cue = tt.activeCues && tt.activeCues[0]
    this.renderCue(cue ? cue.text : "")
  }

  renderCue(text) {
    if (!this.hasCaptionsTarget) return
    this.captionsTarget.textContent = ""
    if (text) {
      String(text).split("\n").forEach((line, i) => {
        if (i) this.captionsTarget.appendChild(document.createElement("br"))
        this.captionsTarget.appendChild(document.createTextNode(line))
      })
    }
    this.updateCaptionsVisibility()
  }

  updateCaptionsVisibility() {
    if (!this.hasCaptionsTarget) return
    this.captionsTarget.hidden = !(this.subEnabled && this.captionsTarget.textContent.length > 0)
  }

  applyCaptionStyle({ textColor, background, fontSize, fontWeight } = {}) {
    if (!this.hasCaptionsTarget) return
    const el = this.captionsTarget
    if (textColor != null) el.style.setProperty("--subtitle-color", textColor)
    if (fontSize != null) el.style.setProperty("--subtitle-size", fontSize)
    if (fontWeight != null) el.style.setProperty("--subtitle-weight", fontWeight)
    if (background !== undefined) el.style.setProperty("--subtitle-bg", background ? background : "transparent")
  }

  onSubtitlesToggle(event) {
    this.subEnabled = !!(event.detail && event.detail.enabled)
    if (this.subEnabled && this.activeTrackId == null && this.tracks && this.tracks.length) {
      const sel = this.tracks.find((t) => t.default) || this.tracks[0]
      this.selectTrack(sel.id)
    }
    this.updateCaptionsVisibility()
  }

  onSubtitlesStyle(event) { this.applyCaptionStyle(event.detail || {}) }

  onSubtitlesLanguage(event) {
    if (event.detail && event.detail.trackId) this.selectTrack(event.detail.trackId)
  }

  // --- controls --------------------------------------------------------------

  // Clicking anywhere on the DOCKED player — except a control button (close,
  // play/pause) — opens the full player page for the current video. Reads DOM
  // state (class/hidden/dataset), which survives the permanent-element reconnect.
  openVideo(event) {
    if (this.element.hidden) return
    if (this.element.classList.contains("mini-player--expanded")) return
    if (event && event.target.closest("button")) return // let the control act
    const slug = this.element.dataset.slug
    if (slug) this.visit(`/playing/${slug}`)
  }

  toggle() {
    if (this.videoTarget.paused) this.videoTarget.play()
    else this.videoTarget.pause()
  }

  skipForward() { this.seek(5) }
  skipBack() { this.seek(-5) }

  seek(delta) {
    const max = this.videoTarget.duration || Infinity
    this.videoTarget.currentTime = Math.min(Math.max(this.videoTarget.currentTime + delta, 0), max)
    this.activity()
  }

  prev() { this.saveProgress(); this.visit(this.desc.prevUrl) }
  next() { this.saveProgress(); this.visit(this.desc.nextUrl) }

  visit(url) {
    if (!url) return
    if (window.Turbo) window.Turbo.visit(url)
    else window.location.assign(url)
  }

  // Close (X): stop + remove; stays dismissed until a new video is started.
  close() {
    this.saveProgress()
    this.videoTarget.pause()
    this.videoTarget.removeAttribute("src")
    this.videoTarget.load()
    this.currentSlug = null
    this.dismissed = true
    this.element.hidden = true
    this.element.classList.remove("is-controls", "is-active")
    this.teardownMediaSession()
  }

  toggleFullscreen() {
    const el = this.element
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      (document.exitFullscreen || document.webkitExitFullscreen)?.call(document)
    } else {
      const request = el.requestFullscreen || el.webkitRequestFullscreen
      // Landscape is the only usable orientation for video on a handheld. The
      // Screen Orientation API only permits a lock while fullscreen, so this
      // has to wait for the request to resolve. No device sniffing: lock()
      // rejects wherever it isn't supported (desktop, iOS Safari), which is the
      // intended no-op. "landscape" rather than "landscape-primary" so the
      // viewer can still flip the phone 180°.
      Promise.resolve(request?.call(el))
        .then(() => screen.orientation?.lock?.("landscape"))
        .catch(() => {})
    }
  }

  // Leaving fullscreen should hand rotation back to the viewer. Browsers are
  // specified to release the lock on exit, but a lock that outlived fullscreen
  // would pin the whole site to landscape — too costly a failure to rely on it.
  onFullscreenChange() {
    if (document.fullscreenElement || document.webkitFullscreenElement) return
    try { screen.orientation?.unlock?.() } catch { /* unsupported */ }
  }

  // --- playback state --------------------------------------------------------

  onPlay() {
    this.element.classList.add("is-playing")
    this.setupMediaSession()
    if ("mediaSession" in navigator) navigator.mediaSession.playbackState = "playing"
    this.recordView()
    this.activity()
  }

  onPause() {
    this.element.classList.remove("is-playing")
    if ("mediaSession" in navigator) navigator.mediaSession.playbackState = "paused"
    this.saveProgress()
    if (this.expanded) this.activity()
  }

  onLoadedMetadata() {
    const r = this.resume
    if (r > 0 && r < (this.videoTarget.duration || Infinity) - 5) this.videoTarget.currentTime = r
    this.updateTimeline()
  }

  // --- timeline / seek -------------------------------------------------------

  updateTimeline() {
    const v = this.videoTarget
    const dur = v.duration || 0
    if (this.hasTimelineFillTarget) {
      this.timelineFillTarget.style.width = dur ? `${(v.currentTime / dur) * 100}%` : "0%"
    }
    if (this.hasCurrentTimeTarget) this.currentTimeTarget.textContent = this.formatTime(v.currentTime)
    if (this.hasDurationTarget) this.durationTarget.textContent = this.formatTime(dur)
  }

  scrubStart(event) {
    event.preventDefault()
    this.seekToEvent(event)
    const move = (e) => this.seekToEvent(e)
    const up = () => {
      document.removeEventListener("pointermove", move)
      document.removeEventListener("pointerup", up)
    }
    document.addEventListener("pointermove", move)
    document.addEventListener("pointerup", up)
  }

  seekToEvent(event) {
    if (!this.hasTimelineTarget) return
    const rect = this.timelineTarget.getBoundingClientRect()
    const pct = Math.min(Math.max((event.clientX - rect.left) / rect.width, 0), 1)
    const dur = this.videoTarget.duration
    if (dur) {
      this.videoTarget.currentTime = pct * dur
      this.updateTimeline()
    }
    this.activity()
  }

  // M:SS up to 59:59, then H:MM:SS once the video crosses the hour mark.
  formatTime(seconds) {
    const s = Math.floor(seconds || 0)
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = (s % 60).toString().padStart(2, "0")
    if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${sec}`
    return `${m}:${sec}`
  }

  // --- autoplay-next (US5) ---------------------------------------------------

  onEnded() {
    if (!this.autoplayValue || this.dismissed) return
    if (this.expanded && this.desc.nextUrl) {
      // Explicit sequence next — full navigation refreshes the page chrome; the
      // persistent <video> survives the #page-content swap.
      sessionStorage.setItem(ADVANCE_KEY, "1")
      this.visit(this.desc.nextUrl)
    } else {
      this.advanceViaUpNext(this.expanded)
    }
  }

  async advanceViaUpNext(navigate) {
    if (!this.desc.upNextUrl) return
    const url = new URL(this.desc.upNextUrl, window.location.origin)
    url.searchParams.set("played", this.chain().join(","))
    let data
    try {
      const res = await fetch(url, {
        headers: { Accept: "application/json", "X-Pin-Unlock": this.pinToken() },
        credentials: "same-origin"
      })
      if (res.status === 204 || !res.ok) return // nothing eligible → stop
      data = await res.json()
    } catch (_) { return }
    if (!data || !data.src) return

    if (navigate) {
      sessionStorage.setItem(ADVANCE_KEY, "1")
      this.visit(`/playing/${data.slug}`)
    } else {
      this.pushChain(this.currentSlug)
      document.dispatchEvent(new CustomEvent("mini-player:load", {
        detail: { ...data, expanded: false, viaAutoplay: true }
      }))
    }
  }

  // --- autoplay preference ---------------------------------------------------

  // Kept in sync by the toggle (dispatched from the player page).
  setAutoplay(event) {
    if (event && event.detail && typeof event.detail.enabled === "boolean") {
      this.autoplayValue = event.detail.enabled
    }
  }

  // --- Media Session (US3) ---------------------------------------------------

  setupMediaSession() {
    if (!("mediaSession" in navigator)) return
    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: this.desc.title || "",
        album: this.desc.album || "DevCine",
        artwork: this.desc.artwork ? [{ src: this.desc.artwork, sizes: "512x512" }] : []
      })
    } catch (_) { /* unsupported */ }
    if (this.mediaReady) return
    this.mediaReady = true
    const set = (a, cb) => { try { navigator.mediaSession.setActionHandler(a, cb) } catch (_) {} }
    set("play", () => this.videoTarget.play())
    set("pause", () => this.videoTarget.pause())
    set("seekbackward", () => this.seek(-5))
    set("seekforward", () => this.seek(5))
    set("previoustrack", () => this.prev())
    set("nexttrack", () => this.next())
  }

  teardownMediaSession() {
    if (!this.mediaReady || !("mediaSession" in navigator)) return
    ;["play", "pause", "seekbackward", "seekforward", "previoustrack", "nexttrack"]
      .forEach((a) => { try { navigator.mediaSession.setActionHandler(a, null) } catch (_) {} })
    try { navigator.mediaSession.metadata = null } catch (_) {}
    this.mediaReady = false
  }

  // --- watch history + resume ------------------------------------------------

  recordView() {
    if (this.viewRecorded || !this.desc.viewsUrl) return
    this.viewRecorded = true
    this.post(this.desc.viewsUrl)
  }

  onTimeUpdate() {
    this.updateTimeline()
    const now = this.videoTarget.currentTime
    if (now - this.lastSavedAt >= this.constructor.PROGRESS_INTERVAL || now < this.lastSavedAt) {
      this.saveProgress()
    }
  }

  saveProgress() {
    if (!this.desc || !this.desc.progressUrl) return
    const position = Math.floor(this.videoTarget.currentTime || 0)
    if (position <= 0) return
    this.lastSavedAt = this.videoTarget.currentTime
    const duration = Math.floor(this.videoTarget.duration || 0)
    this.post(`${this.desc.progressUrl}?position=${position}&duration=${duration}`, true)
  }

  // --- idle auto-hide (expanded only) ----------------------------------------

  activity() {
    if (!this.expanded) return
    this.element.classList.add("is-active")
    clearTimeout(this.hideTimer)
    this.hideTimer = setTimeout(() => {
      if (!this.videoTarget.paused) this.element.classList.remove("is-active")
    }, 2000)
  }

  // --- keyboard --------------------------------------------------------------

  onKey(event) {
    if (this.element.hidden || event.metaKey || event.ctrlKey || event.altKey) return
    const el = event.target
    if (el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName))) return
    if (event.key === "f" || event.key === "F") {
      if (!this.expanded) return
      event.preventDefault()
      this.toggleFullscreen()
    } else if (event.key === " " || event.code === "Space") {
      event.preventDefault()
      this.toggle()
      this.activity()
    } else if (event.key === "i" || event.key === "I") {
      // Minimize: leave the player page for the last real page (back_navigation
      // stack). The stream nav swaps only #page-content, so playback continues
      // and the player docks itself via the player-source disconnect.
      if (!this.expanded) return
      event.preventDefault()
      document.dispatchEvent(new CustomEvent("back-navigation:back"))
    }
  }

  // --- helpers ---------------------------------------------------------------

  chain() {
    try { return JSON.parse(sessionStorage.getItem(CHAIN_KEY)) || [] } catch (_) { return [] }
  }
  setChain(arr) { try { sessionStorage.setItem(CHAIN_KEY, JSON.stringify(arr)) } catch (_) {} }
  pushChain(slug) {
    if (!slug) return
    const c = this.chain()
    if (!c.includes(slug)) { c.push(slug); this.setChain(c) }
  }

  pinToken() {
    const ev = new CustomEvent("pin-lock:request-token", { detail: { token: "" } })
    document.dispatchEvent(ev)
    return ev.detail.token || ""
  }

  post(url, keepalive = false) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": token, Accept: "text/plain" },
      credentials: "same-origin",
      keepalive
    }).catch(() => {})
  }
}
