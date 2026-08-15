import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

// The teacher's phone. Optimistic UI: advance locally on tap, PATCH in the
// background, reconcile from the broadcast — safe because state is absolute.
// While disconnected, Prev/Next is script-browsing only ("read ahead"); on
// reconnect the phone rejoins the board's reality, not its own.
export default class extends Controller {
  static targets = [
    "page", "title", "nextTitle", "counter", "timer", "live",
    "indicatorDot", "indicatorLabel", "awake",
    "readAhead", "resyncNotice", "endConfirm"
  ]
  static values = {
    page: Number,
    pageCount: Number,
    started: Boolean,
    token: String,
    updateUrl: String,
    stateUrl: String,
    strings: Object
  }

  connect() {
    this.serverPage = this.pageValue
    this.online = false

    this.subscription = consumer.subscriptions.create(
      { channel: "TeachSessionChannel", token: this.tokenValue },
      {
        connected: ({ reconnected } = {}) => this.cableConnected(reconnected),
        disconnected: () => this.setIndicator("warn", this.stringsValue.reconnecting),
        rejected: () => this.setIndicator("err", this.stringsValue.disconnected),
        received: (data) => this.received(data)
      }
    )

    // ActionCable's client has no online/offline handling; wifi→cellular with
    // the screen on is otherwise only caught by the 6s stale threshold.
    this.reopen = () => consumer.connection.reopen()
    window.addEventListener("online", this.reopen)

    // Screen Wake Lock: the lock drops whenever the tab hides (and iOS
    // suspends the websocket on lock) — re-request on return.
    this.visibility = () => {
      if (document.visibilityState === "visible") {
        this.keepAwake()
        consumer.connection.reopen()
      }
    }
    document.addEventListener("visibilitychange", this.visibility)
    this.keepAwake()

    if (this.startedValue) {
      this.showPage(this.pageValue, { announce: false })
      this.startTimer()
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
    window.removeEventListener("online", this.reopen)
    document.removeEventListener("visibilitychange", this.visibility)
    clearInterval(this.timerInterval)
    clearTimeout(this.resyncNoticeTimer)
    this.wakeLock?.release().catch(() => {})
  }

  // --- Cable ---

  cableConnected(reconnected) {
    this.online = true
    this.setIndicator("ok", this.stringsValue.connected)
    if (reconnected) this.resync()
  }

  received(data) {
    if (data.ended) { window.location.assign("/"); return }
    if (typeof data.page === "number") {
      this.serverPage = data.page
      this.hideReadAhead()
      if (this.startedValue && data.page !== this.pageValue) this.showPage(data.page)
    }
  }

  async resync() {
    try {
      const response = await fetch(this.stateUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const state = await response.json()
      if (state.ended) { window.location.assign("/"); return }
      this.serverPage = state.page
      this.hideReadAhead()
      if (this.startedValue && state.page !== this.pageValue) {
        this.showPage(state.page)
        this.flashResyncNotice(state.page)
      }
    } catch {}
  }

  // --- Navigation ---

  next() { this.advanceTo(this.pageValue + 1) }
  prev() { this.advanceTo(this.pageValue - 1) }

  advanceTo(page) {
    const clamped = Math.min(Math.max(page, 1), this.pageCountValue)
    if (clamped === this.pageValue) return

    this.showPage(clamped)

    if (this.online) {
      this.patchPage(clamped)
    } else {
      // Read ahead only: never claim to move the board while offline.
      this.readAheadTarget.classList.remove("hidden")
    }
  }

  async patchPage(page) {
    try {
      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ page })
      })
      if (response.ok) this.serverPage = page
    } catch {
      this.readAheadTarget.classList.remove("hidden")
    }
  }

  showPage(page, { announce = true } = {}) {
    this.pageValue = page

    this.pageTargets.forEach((section) => {
      section.classList.toggle("hidden", Number(section.dataset.page) !== page)
    })

    const current = this.pageTargets.find((s) => Number(s.dataset.page) === page)
    const next = this.pageTargets.find((s) => Number(s.dataset.page) === page + 1)

    if (this.hasTitleTarget) this.titleTarget.textContent = current?.dataset.title || ""
    if (this.hasNextTitleTarget) {
      this.nextTitleTarget.textContent = next
        ? this.format(this.stringsValue.next_up, { title: next.dataset.title })
        : this.stringsValue.end_of_deck
    }
    if (this.hasCounterTarget) this.counterTarget.textContent = `${page} / ${this.pageCountValue}`
    if (announce && this.hasLiveTarget) {
      this.liveTarget.textContent = this.format(this.stringsValue.announce, {
        page, count: this.pageCountValue
      })
    }

    this.resetTimer()
  }

  // --- Per-slide timer: elapsed (never a countdown), reset on advance ---

  startTimer() {
    this.slideStartedAt = Date.now()
    this.renderTimer()
    this.timerInterval = setInterval(() => this.renderTimer(), 1000)
  }

  resetTimer() {
    this.slideStartedAt = Date.now()
    this.renderTimer()
  }

  renderTimer() {
    if (!this.hasTimerTarget || !this.slideStartedAt) return
    const elapsed = Math.floor((Date.now() - this.slideStartedAt) / 1000)
    const current = this.pageTargets.find((s) => Number(s.dataset.page) === this.pageValue)
    const target = Number(current?.dataset.suggestedSeconds)
    this.timerTarget.textContent = target
      ? `${this.clock(elapsed)} / ${this.clock(target)}`
      : this.clock(elapsed)
  }

  clock(totalSeconds) {
    const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, "0")
    const seconds = String(totalSeconds % 60).padStart(2, "0")
    return `${minutes}:${seconds}`
  }

  // --- Connection indicator: colour is never the only signal ---

  setIndicator(level, label) {
    if (level !== "ok") this.online = false
    if (this.hasIndicatorDotTarget) {
      this.indicatorDotTarget.classList.remove("bg-conn-ok", "bg-conn-warn", "bg-conn-err")
      this.indicatorDotTarget.classList.add(`bg-conn-${level}`)
    }
    if (this.hasIndicatorLabelTarget) this.indicatorLabelTarget.textContent = label
  }

  hideReadAhead() {
    if (this.hasReadAheadTarget) this.readAheadTarget.classList.add("hidden")
  }

  flashResyncNotice(page) {
    if (!this.hasResyncNoticeTarget) return
    this.resyncNoticeTarget.textContent = this.format(this.stringsValue.back_on, { page })
    this.resyncNoticeTarget.classList.remove("hidden")
    clearTimeout(this.resyncNoticeTimer)
    this.resyncNoticeTimer = setTimeout(() => this.resyncNoticeTarget.classList.add("hidden"), 4000)
  }

  // --- Wake lock ---

  async keepAwake() {
    if (!("wakeLock" in navigator)) return // fall back silently
    try {
      this.wakeLock = await navigator.wakeLock.request("screen")
      this.awakeTarget.classList.remove("hidden")
      this.wakeLock.addEventListener("release", () => this.awakeTarget.classList.add("hidden"))
    } catch {}
  }

  // --- End confirmation (in-page, never window.confirm) ---

  confirmEnd() { this.endConfirmTarget.classList.remove("hidden") }
  cancelEnd() { this.endConfirmTarget.classList.add("hidden") }

  format(template, substitutions) {
    return Object.entries(substitutions).reduce(
      (result, [key, value]) => result.replaceAll(`%{${key}}`, value),
      template || ""
    )
  }
}
