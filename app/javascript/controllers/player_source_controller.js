import { Controller } from "@hotwired/stimulus"

// Lives on the player page (inside #page-content, feature 010). It carries the
// current video's descriptor and hands it to the persistent mini-player:
//   connect    → mini-player:load (expanded, over #player-stage)
//   disconnect → mini-player:dock (navigating away → shrink to the corner)
// It renders no media itself; the single <video> lives in the layout host.
export default class extends Controller {
  static values = {
    slug: String, src: String, artwork: String, title: String, album: String,
    prevUrl: String, nextUrl: String, resume: Number, list: String,
    viewsUrl: String, progressUrl: String, upNextUrl: String,
    // Subtitles (feature 012): per-video tracks + per-user prefs.
    subtitles: Array, subEnabled: Boolean, subTextColor: String,
    subBgColor: String, subFontSize: Number, subFontWeight: Number
  }

  connect() {
    if (!this.srcValue) return // live embeds / unavailable videos: nothing to host
    // Dispatch now (the persistent player is already alive across Turbo Drive
    // visits) AND re-dispatch when the player announces it just connected, so a
    // full/direct page load — where this controller may connect first — isn't a
    // missed handshake.
    this.dispatchLoad = this.dispatchLoad.bind(this)
    document.addEventListener("mini-player:connected", this.dispatchLoad)
    this.dispatchLoad()
  }

  disconnect() {
    document.removeEventListener("mini-player:connected", this.dispatchLoad)
    document.dispatchEvent(new CustomEvent("mini-player:dock"))
  }

  dispatchLoad() {
    document.dispatchEvent(new CustomEvent("mini-player:load", {
      detail: {
        slug: this.slugValue,
        src: this.srcValue,
        artwork: this.artworkValue,
        title: this.titleValue,
        album: this.albumValue,
        prevUrl: this.prevUrlValue,
        nextUrl: this.nextUrlValue,
        resume: this.resumeValue,
        list: this.listValue,
        viewsUrl: this.viewsUrlValue,
        progressUrl: this.progressUrlValue,
        upNextUrl: this.upNextUrlValue,
        subtitles: this.subtitlesValue,
        subEnabled: this.subEnabledValue,
        subTextColor: this.subTextColorValue,
        subBgColor: this.subBgColorValue,
        subFontSize: this.subFontSizeValue,
        subFontWeight: this.subFontWeightValue,
        expanded: true
      }
    }))
  }
}
