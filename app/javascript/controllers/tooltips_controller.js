import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  #generatedTitles = new WeakMap()

  connect() {
    this.update()
    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  update() {
    for (const control of this.element.querySelectorAll("a, button, label")) {
      const previousTitle = this.#generatedTitles.get(control)

      // Explicit titles (including empty ones) take precedence over generated hints.
      if (control.hasAttribute("title") && control.title !== previousTitle) continue

      const text = Array.from(control.querySelectorAll(".for-screen-reader"))
        .filter(label => label.closest("a, button, label") === control)
        .map(label => label.textContent.trim())
        .filter(Boolean)
        .join(" ")
        .replace(/\s+/g, " ")

      if (text) {
        control.title = text
        this.#generatedTitles.set(control, text)
      } else if (previousTitle !== undefined) {
        control.removeAttribute("title")
        this.#generatedTitles.delete(control)
      }
    }
  }
}
