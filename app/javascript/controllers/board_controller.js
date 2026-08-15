import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

// The projector. States: waiting → holding → teaching → ended → waiting
// (auto, new code). Slides are all preloaded in the DOM; advancing is a
// class toggle — a dropped websocket never blanks the projector.
export default class extends Controller {
  static targets = ["slide", "holding", "countdown"]
  static values = {
    state: String,
    token: String,
    page: Number,
    pageCount: Number,
    codeExpiresIn: Number,
    stateUrl: String,
    pageUrl: String,
    endUrl: String,
    refreshUrl: String
  }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "TeachSessionChannel", token: this.tokenValue },
      {
        connected: ({ reconnected } = {}) => { if (reconnected) this.resync() },
        received: (data) => this.received(data)
      }
    )

    // ActionCable's client has no online/offline handling of its own.
    this.reopen = () => consumer.connection.reopen()
    window.addEventListener("online", this.reopen)

    this.keydown = (event) => this.handleKey(event)
    window.addEventListener("keydown", this.keydown)

    // Test/diagnostic hook: force a resync without a cable event.
    this.forceResync = () => this.resync()
    window.addEventListener("board:resync", this.forceResync)

    if (this.stateValue === "waiting") {
      this.startCountdown()
    } else {
      this.installCursorHider()
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
    window.removeEventListener("online", this.reopen)
    window.removeEventListener("keydown", this.keydown)
    window.removeEventListener("board:resync", this.forceResync)
    clearInterval(this.countdownTimer)
    clearTimeout(this.cursorTimer)
    window.removeEventListener("mousemove", this.mousemove)
  }

  received(data) {
    if (data.ended) { this.refresh(); return }
    if (data.paired) { this.refresh(); return }
    if (data.started) { this.enterTeaching(); return }
    if (typeof data.page === "number" && this.stateValue === "teaching") this.show(data.page)
  }

  // Re-read { page, started, ended } from the DB-backed state endpoint — a
  // board reconnecting during pre-flight lands on holding, never slide 1.
  async resync() {
    if (this.stateValue === "waiting") { this.refresh(); return }
    try {
      const response = await fetch(this.stateUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) { this.refresh(); return }
      const state = await response.json()
      if (state.ended) { this.refresh(); return }
      if (state.started) { this.enterTeaching(); this.show(state.page) } else { this.enterHolding() }
    } catch {
      // Still offline; keep showing the current slide.
    }
  }

  show(page) {
    this.pageValue = page
    this.slideTargets.forEach((img) => {
      img.classList.toggle("is-active", Number(img.dataset.page) === page)
    })
  }

  enterTeaching() {
    this.stateValue = "teaching"
    if (this.hasHoldingTarget) this.holdingTarget.classList.add("hidden")
    this.show(this.pageValue || 1)
  }

  enterHolding() {
    this.stateValue = "holding"
    if (this.hasHoldingTarget) this.holdingTarget.classList.remove("hidden")
  }

  // Keyboard fallback: if the phone dies, the teacher walks to the PC and
  // keeps going; Esc ends the session so a fresh code appears (recovery).
  handleKey(event) {
    if (event.key === "Escape" && this.stateValue !== "waiting") { this.endSession(); return }
    if (this.stateValue !== "teaching") return

    if (event.key === "ArrowRight" || event.key === " ") {
      event.preventDefault()
      this.advanceTo(this.pageValue + 1)
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.advanceTo(this.pageValue - 1)
    }
  }

  async advanceTo(page) {
    const clamped = Math.min(Math.max(page, 1), this.pageCountValue)
    if (clamped === this.pageValue) return
    this.show(clamped)
    try {
      await fetch(this.pageUrlValue, {
        method: "PATCH",
        headers: this.headers(),
        body: JSON.stringify({ page: clamped })
      })
    } catch {
      // Offline: the local toggle already happened; DB catches up on resync.
    }
  }

  async endSession() {
    try { await fetch(this.endUrlValue, { method: "PATCH", headers: this.headers() }) } catch {}
    this.refresh()
  }

  // Ended/paired/expired: fetch a fresh page (and, when unpaired/ended, a
  // fresh session + code) — the teacher never touches the classroom PC.
  refresh() {
    if (window.Turbo) {
      window.Turbo.visit(this.refreshUrlValue, { action: "replace" })
    } else {
      window.location.assign(this.refreshUrlValue)
    }
  }

  startCountdown() {
    let remaining = this.codeExpiresInValue
    const render = () => {
      const clamped = Math.max(remaining, 0)
      const minutes = Math.floor(clamped / 60)
      const seconds = String(clamped % 60).padStart(2, "0")
      if (this.hasCountdownTarget) this.countdownTarget.textContent = `${minutes}:${seconds}`
    }
    render()
    this.countdownTimer = setInterval(() => {
      remaining -= 1
      render()
      if (remaining <= 0) this.refresh() // expired code → new session + code
    }, 1000)
  }

  // The slide and nothing else: hide the cursor after 2s idle.
  installCursorHider() {
    const arm = () => {
      this.element.classList.remove("cursor-hidden")
      clearTimeout(this.cursorTimer)
      this.cursorTimer = setTimeout(() => this.element.classList.add("cursor-hidden"), 2000)
    }
    this.mousemove = arm
    window.addEventListener("mousemove", this.mousemove)
    arm()
  }

  async fullscreen() {
    try {
      // Progressive enhancement (Chromium): place the window on the external
      // display before going fullscreen.
      if ("getScreenDetails" in window) {
        const details = await window.getScreenDetails()
        const external = details.screens.find((screen) => screen !== details.currentScreen)
        if (external) {
          await this.element.requestFullscreen({ screen: external })
          return
        }
      }
    } catch {
      // Permission denied or single display — fall through.
    }
    this.element.requestFullscreen?.()
  }

  headers() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
    }
  }
}
