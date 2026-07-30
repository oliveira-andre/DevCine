import { Controller } from "@hotwired/stimulus"

// Back-navigation for the stream-nav shell (feature 010 refactor; spotsby's
// back_link idea). Attached to <body>. Three jobs:
//
// 1. TRACK: keep a session nav stack of non-player pages so "minimize" (the
//    "i" key on the player) can return to the last real page.
// 2. URLS: Turbo stream navigations don't touch history, so on every
//    a[data-turbo-stream] click we pushState the destination — the address bar,
//    refresh, and share links stay truthful.
// 3. BACK/FORWARD: on popstate, do a classic Turbo Drive visit of the current
//    URL — the mini-player's data-turbo-permanent safety net carries playback
//    through it.
const STACK_KEY = "devcine:nav-stack"
const STACK_MAX = 30

export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    this.onPopstate = this.onPopstate.bind(this)
    this.onBack = this.onBack.bind(this)
    document.addEventListener("click", this.onClick, true)
    window.addEventListener("popstate", this.onPopstate)
    document.addEventListener("back-navigation:back", this.onBack)
    // Full loads / Drive visits reconnect this controller — record the landing page.
    this.record(location.pathname + location.search)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick, true)
    window.removeEventListener("popstate", this.onPopstate)
    document.removeEventListener("back-navigation:back", this.onBack)
  }

  // Capture-phase: runs before Turbo handles the click.
  onClick(event) {
    const link = event.target.closest("a[data-turbo-stream]")
    if (!link || link.origin !== location.origin) return

    const dest = link.pathname + link.search
    if (dest !== location.pathname + location.search) {
      history.pushState({ devcine: true }, "", dest)
    }
    // Synthetic back-links must not re-record their destination.
    if (link.dataset.backNav !== "true") this.record(dest)
    window.scrollTo(0, 0)
  }

  onPopstate() {
    if (window.Turbo) window.Turbo.visit(location.href, { action: "replace" })
    else window.location.reload()
  }

  // "Minimize" (i on the player, or any back affordance): stream-navigate to the
  // last non-player page. Routed through a real <a data-turbo-stream> click so
  // the request flows through Turbo's pipeline (pin-unlock header, events, and
  // our own pushState above).
  onBack() {
    const stack = this.read()
    const here = location.pathname + location.search
    let dest = stack[stack.length - 1]
    if (dest === here) dest = stack[stack.length - 2]
    this.navigate(dest || "/")
  }

  navigate(url) {
    const a = document.createElement("a")
    a.href = url
    a.dataset.turboStream = "true"
    a.dataset.backNav = "true"
    a.hidden = true
    document.body.appendChild(a)
    a.click()
    a.remove()
  }

  // --- stack helpers ---------------------------------------------------------

  record(dest) {
    if (dest.startsWith("/playing/")) return // player views are never "back" targets
    const stack = this.read()
    if (stack[stack.length - 1] !== dest) stack.push(dest)
    this.write(stack.slice(-STACK_MAX))
  }

  read() {
    try { return JSON.parse(sessionStorage.getItem(STACK_KEY)) || [] } catch (_) { return [] }
  }

  write(stack) {
    try { sessionStorage.setItem(STACK_KEY, JSON.stringify(stack)) } catch (_) { /* ignore */ }
  }
}
