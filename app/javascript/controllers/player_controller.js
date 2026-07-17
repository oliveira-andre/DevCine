import { Controller } from "@hotwired/stimulus"

// Pseudo-player (feature 005). Drives a controls-less <video>: play/pause,
// skip ±5s, fullscreen, idle auto-hide (3s), Media Session, watch history, and
// resume position (WatchProgress). It NEVER auto-pauses on lifecycle/lock/
// visibility events (Constitution V) — pause only happens from the on-screen
// control or a Media Session action.
export default class extends Controller {
  static targets = ["video", "controls"]
  static values = {
    viewsUrl: String, progressUrl: String, resume: Number,
    title: String, artwork: String
  }

  static PROGRESS_INTERVAL = 10 // seconds between progress saves while playing

  connect() {
    this.hideTimer = null
    this.viewRecorded = false
    this.mediaReady = false
    this.lastSavedAt = 0
    this.onPlay = this.onPlay.bind(this)
    this.onPause = this.onPause.bind(this)
    this.onTimeUpdate = this.onTimeUpdate.bind(this)
    this.onLoadedMetadata = this.onLoadedMetadata.bind(this)
    this.onPageHide = this.onPageHide.bind(this)
    if (this.hasVideoTarget) {
      this.videoTarget.addEventListener("play", this.onPlay)
      this.videoTarget.addEventListener("pause", this.onPause)
      this.videoTarget.addEventListener("timeupdate", this.onTimeUpdate)
      this.videoTarget.addEventListener("loadedmetadata", this.onLoadedMetadata)
      window.addEventListener("pagehide", this.onPageHide)
    }
    this.activity()
  }

  disconnect() {
    clearTimeout(this.hideTimer)
    if (this.hasVideoTarget) {
      this.saveProgress() // persist the position when Turbo navigates away
      this.videoTarget.removeEventListener("play", this.onPlay)
      this.videoTarget.removeEventListener("pause", this.onPause)
      this.videoTarget.removeEventListener("timeupdate", this.onTimeUpdate)
      this.videoTarget.removeEventListener("loadedmetadata", this.onLoadedMetadata)
      window.removeEventListener("pagehide", this.onPageHide)
    }
    this.teardownMediaSession()
  }

  // --- playback (US1) ---
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

  // Next/previous video are placeholders for now (FR-007).
  prev() {}
  next() {}

  // --- fullscreen (FR-023) ---
  toggleFullscreen() {
    const el = this.element
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      (document.exitFullscreen || document.webkitExitFullscreen)?.call(document)
    } else {
      (el.requestFullscreen || el.webkitRequestFullscreen)?.call(el)
    }
  }

  // --- state ---
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
    this.showControls()
  }

  // Resume where the viewer stopped (skips when within 5s of the end).
  onLoadedMetadata() {
    const resume = this.resumeValue
    if (resume > 0 && resume < (this.videoTarget.duration || Infinity) - 5) {
      this.videoTarget.currentTime = resume
    }
  }

  // --- idle auto-hide (US3) ---
  activity() {
    this.showControls()
    clearTimeout(this.hideTimer)
    this.hideTimer = setTimeout(() => {
      if (this.hasVideoTarget && !this.videoTarget.paused) this.element.classList.remove("is-active")
    }, 3000)
  }

  showControls() { this.element.classList.add("is-active") }

  // --- Media Session (US2, FR-027) ---
  setupMediaSession() {
    if (this.mediaReady || !("mediaSession" in navigator)) return
    this.mediaReady = true
    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: this.titleValue,
        artwork: this.artworkValue ? [{ src: this.artworkValue, sizes: "512x512" }] : []
      })
    } catch (_) { /* MediaMetadata unsupported */ }
    const set = (action, cb) => { try { navigator.mediaSession.setActionHandler(action, cb) } catch (_) {} }
    set("play", () => this.videoTarget.play())
    set("pause", () => this.videoTarget.pause())
    set("seekbackward", () => this.seek(-5))
    set("seekforward", () => this.seek(5))
    set("previoustrack", () => this.prev())
    set("nexttrack", () => this.next())
  }

  // Clear handlers on navigation so the OS controls don't call a detached controller.
  teardownMediaSession() {
    if (!this.mediaReady || !("mediaSession" in navigator)) return
    const clear = (action) => { try { navigator.mediaSession.setActionHandler(action, null) } catch (_) {} }
    ;["play", "pause", "seekbackward", "seekforward", "previoustrack", "nexttrack"].forEach(clear)
    try { navigator.mediaSession.metadata = null } catch (_) {}
  }

  // --- watch history (US6, FR-018) ---
  recordView() {
    if (this.viewRecorded || !this.hasViewsUrlValue) return
    this.viewRecorded = true
    this.post(this.viewsUrlValue)
  }

  // --- resume position (WatchProgress) ---
  onTimeUpdate() {
    const now = this.videoTarget.currentTime
    if (now - this.lastSavedAt >= this.constructor.PROGRESS_INTERVAL || now < this.lastSavedAt) {
      this.saveProgress()
    }
  }

  onPageHide() { this.saveProgress() }

  saveProgress() {
    if (!this.hasProgressUrlValue || !this.hasVideoTarget) return
    const position = Math.floor(this.videoTarget.currentTime || 0)
    if (position <= 0) return
    this.lastSavedAt = this.videoTarget.currentTime
    const duration = Math.floor(this.videoTarget.duration || 0)
    this.post(`${this.progressUrlValue}?position=${position}&duration=${duration}`, true)
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
