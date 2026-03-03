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

applyTheme(localStorage.getItem("theme") || "system");

window.addEventListener("phx:cycle-theme", () => {
  const current = localStorage.getItem("theme") || "system";
  const next = themes[(themes.indexOf(current) + 1) % themes.length];
  applyTheme(next);
});

window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
  if ((localStorage.getItem("theme") || "system") === "system") applyTheme("system");
});

// ---- Chart Colors (theme-safe rgba) ----
const C = {
  won:     "rgba(34, 197, 94,  0.85)",
  lost:    "rgba(248, 113, 113, 0.85)",
  pending: "rgba(100, 116, 139, 0.4)",
  neutral: "rgba(100, 116, 139, 0.4)",
  tick:    "rgba(128, 128, 128, 0.8)",
  grid:    "rgba(128, 128, 128, 0.1)",
};

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
  },

  BetStatusChart: {
    mounted() {
      const el = this.el;
      const canvas = el.querySelector("#bet-status-canvas");
      this._chart = new Chart(canvas, {
        type: "doughnut",
        data: {
          labels: ["Won", "Lost", "Pending"],
          datasets: [{
            data: [
              parseInt(el.dataset.won),
              parseInt(el.dataset.lost),
              parseInt(el.dataset.pending),
            ],
            backgroundColor: [C.won, C.lost, C.pending],
            borderWidth: 0,
            hoverOffset: 6,
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: "70%",
          plugins: {
            legend: {
              position: "bottom",
              labels: { color: C.tick, font: { size: 11 }, padding: 16 }
            }
          }
        }
      });
    },
    destroyed() { this._chart?.destroy(); }
  },

  MoneyFlowChart: {
    mounted() {
      const el = this.el;
      const canvas = el.querySelector("#money-flow-canvas");
      this._chart = new Chart(canvas, {
        type: "bar",
        data: {
          labels: ["Wagered", "Won", "Lost"],
          datasets: [{
            label: "Amount (Ksh)",
            data: [
              parseFloat(el.dataset.wagered),
              parseFloat(el.dataset.won),
              parseFloat(el.dataset.lost),
            ],
            backgroundColor: [C.neutral, C.won, C.lost],
            borderRadius: 6,
            borderSkipped: false,
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { display: false }, ticks: { color: C.tick } },
            y: { grid: { color: C.grid }, ticks: { color: C.tick, callback: v => "Ksh" + v } }
          }
        }
      });
    },
    destroyed() { this._chart?.destroy(); }
  },

  ProfitBarChart: {
    mounted() {
      const el = this.el;
      const canvas = el.querySelector("#profit-bar-canvas");
      this._chart = new Chart(canvas, {
        type: "bar",
        data: {
          labels: ["Stakes Collected", "Payouts Made"],
          datasets: [{
            data: [
              parseFloat(el.dataset.collected),
              parseFloat(el.dataset.payouts),
            ],
            backgroundColor: [C.won, C.lost],
            borderRadius: 4,
            borderSkipped: false,
          }]
        },
        options: {
          indexAxis: "y",
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { color: C.grid }, ticks: { color: C.tick, callback: v => "Ksh" + v } },
            y: { grid: { display: false }, ticks: { color: C.tick } }
          }
        }
      });
    },
    destroyed() { this._chart?.destroy(); }
  },
 AdminSidebar: {
  mounted() {
    // Sync chevron rotation with collapsed state
    const syncChevron = () => {
      const chevron = this.el.querySelector("#sidebar-chevron");
      if (!chevron) return;
      const isCollapsed = document.documentElement.hasAttribute("data-sidebar-collapsed");
      chevron.classList.toggle("rotate-180", !isCollapsed);
      chevron.classList.toggle("rotate-0", isCollapsed);
    };

    syncChevron();

    window.addEventListener("admin:toggle-sidebar", () => {
      const isCollapsed = document.documentElement.hasAttribute("data-sidebar-collapsed");
      if (isCollapsed) {
        document.documentElement.removeAttribute("data-sidebar-collapsed");
        localStorage.setItem("sidebar-collapsed", "false");
      } else {
        document.documentElement.setAttribute("data-sidebar-collapsed", "true");
        localStorage.setItem("sidebar-collapsed", "true");
      }
      syncChevron();
    });

    document.getElementById("sidebar-overlay")?.addEventListener("click", () => {
      window.dispatchEvent(new Event("admin:close-mobile-sidebar"));
    });

    window.addEventListener("admin:close-mobile-sidebar", () => {
      this.el.classList.add("-translate-x-full");
      this.el.classList.remove("translate-x-0");
      document.getElementById("sidebar-overlay")?.classList.add("hidden");
    });

    window.addEventListener("admin:open-mobile-sidebar", () => {
      this.el.classList.remove("-translate-x-full");
      this.el.classList.add("translate-x-0");
      document.getElementById("sidebar-overlay")?.classList.remove("hidden");
    });
  }
},
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
