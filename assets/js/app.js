import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/wazi_bet"
import topbar from "../vendor/topbar"

// ---- Theme ----
const themes = ["system", "light", "dark"];

function applyTheme(theme) {
  localStorage.setItem("theme", theme);
  const resolved = theme === "system"
    ? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    : theme;
  document.documentElement.setAttribute("data-theme", resolved);
}

// Apply saved theme immediately on load
applyTheme(localStorage.getItem("theme") || "system");

window.addEventListener("phx:cycle-theme", () => {
  const current = localStorage.getItem("theme") || "system";
  const next = themes[(themes.indexOf(current) + 1) % themes.length];
  applyTheme(next);
});

// Keep system theme in sync if user changes OS preference
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
  if ((localStorage.getItem("theme") || "system") === "system") applyTheme("system");
});

// ---- Hooks ----
const Hooks = {
  PromoCarousel: {
    mounted() {
      let current = 0;
      const total = 3;
      const track = this.el.querySelector("#carousel-track");
      const dots = this.el.querySelectorAll(".carousel-dot");

      const go = (idx) => {
        current = (idx + total) % total;
        track.style.transform = `translateX(-${(100 / total) * current}%)`;
        dots.forEach((d, i) => {
          d.classList.toggle("bg-base-content", i === current);
          d.classList.toggle("bg-base-content/30", i !== current);
        });
      };

      this.el.querySelector("#carousel-prev").addEventListener("click", () => go(current - 1));
      this.el.querySelector("#carousel-next").addEventListener("click", () => go(current + 1));
      dots.forEach(d => d.addEventListener("click", () => go(+d.dataset.index)));

      this._timer = setInterval(() => go(current + 1), 4000);
    },
    destroyed() { clearInterval(this._timer); }
  }
}

// ---- LiveSocket ----
const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)
    window.liveReloader = reloader
  })
}
