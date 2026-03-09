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
  window.dispatchEvent(new Event("theme:changed"));
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

// ---- Chart Colors (theme-derived) ----
function readThemeColor(className, property = "color") {
  const probe = document.createElement("span");
  probe.className = className;
  probe.style.position = "absolute";
  probe.style.visibility = "hidden";
  probe.style.pointerEvents = "none";
  document.body.appendChild(probe);
  const value = getComputedStyle(probe)[property];
  probe.remove();
  return value;
}

function chartColors() {
  return {
    won: readThemeColor("bg-primary", "backgroundColor"),
    lost: readThemeColor("bg-primary/75", "backgroundColor"),
    pending: readThemeColor("bg-primary/50", "backgroundColor"),
    neutral: readThemeColor("bg-primary/30", "backgroundColor"),
    tick: readThemeColor("text-base-content/80"),
    grid: readThemeColor("text-base-content/12"),
  };
}

function chartFontFamilies() {
  const rootStyles = getComputedStyle(document.documentElement);
  const sans = rootStyles.getPropertyValue("--font-sans").trim() || "system-ui, sans-serif";
  const mono = rootStyles.getPropertyValue("--font-mono").trim() || "ui-monospace, monospace";
  return {sans, mono};
}

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
      const render = () => {
        const C = chartColors();
        const F = chartFontFamilies();
        this._chart?.destroy();
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
                labels: {
                  color: C.tick,
                  font: { family: F.sans, size: 11, weight: 600 },
                  padding: 16
                }
              }
            }
          }
        });
      };

      render();
      this._onThemeChanged = () => render();
      window.addEventListener("theme:changed", this._onThemeChanged);
    },
    destroyed() {
      window.removeEventListener("theme:changed", this._onThemeChanged);
      this._chart?.destroy();
    }
  },

  MoneyFlowChart: {
    mounted() {
      const el = this.el;
      const canvas = el.querySelector("#money-flow-canvas");
      const render = () => {
        const C = chartColors();
        const F = chartFontFamilies();
        this._chart?.destroy();
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
              x: {
                grid: { display: false },
                ticks: { color: C.tick, font: { family: F.sans, size: 11, weight: 500 } }
              },
              y: {
                grid: { color: C.grid },
                ticks: {
                  color: C.tick,
                  font: { family: F.mono, size: 11, weight: 500 },
                  callback: v => "Ksh" + v
                }
              }
            }
          }
        });
      };

      render();
      this._onThemeChanged = () => render();
      window.addEventListener("theme:changed", this._onThemeChanged);
    },
    destroyed() {
      window.removeEventListener("theme:changed", this._onThemeChanged);
      this._chart?.destroy();
    }
  },

  ProfitBarChart: {
    mounted() {
      const el = this.el;
      const canvas = el.querySelector("#profit-bar-canvas");
      const render = () => {
        const C = chartColors();
        const F = chartFontFamilies();
        this._chart?.destroy();
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
              x: {
                grid: { color: C.grid },
                ticks: {
                  color: C.tick,
                  font: { family: F.mono, size: 11, weight: 500 },
                  callback: v => "Ksh" + v
                }
              },
              y: {
                grid: { display: false },
                ticks: { color: C.tick, font: { family: F.sans, size: 11, weight: 500 } }
              }
            }
          }
        });
      };

      render();
      this._onThemeChanged = () => render();
      window.addEventListener("theme:changed", this._onThemeChanged);
    },
    destroyed() {
      window.removeEventListener("theme:changed", this._onThemeChanged);
      this._chart?.destroy();
    }
  },
  FlashToast: {
    mounted() {
      this._progressEl = this.el.querySelector("[data-flash-progress]");
      this._autoclose = this.el.dataset.autoclose !== "false";
      this._duration = parseInt(this.el.dataset.duration || "3500", 10);
      this._duration = Number.isFinite(this._duration) && this._duration > 0 ? this._duration : 3500;

      this._rafId = null;
      this._timerId = null;
      this._startTs = null;
      this._elapsed = 0;
      this._paused = false;

      this._setProgress = (fraction) => {
        if (!this._progressEl) return;
        const clamped = Math.max(0, Math.min(1, fraction));
        this._progressEl.style.width = `${clamped * 100}%`;
      };

      this._tick = (ts) => {
        if (this._paused) return;
        if (this._startTs == null) this._startTs = ts;
        const elapsedInRun = ts - this._startTs;
        const totalElapsed = this._elapsed + elapsedInRun;
        const remaining = Math.max(0, this._duration - totalElapsed);
        this._setProgress(remaining / this._duration);
        if (remaining > 0) {
          this._rafId = requestAnimationFrame(this._tick);
        }
      };

      this._dismiss = () => {
        this._clearTimers();
        this.el.click();
      };

      this._start = () => {
        if (!this._autoclose || this._paused) return;
        this._startTs = null;
        this._clearRaf();
        this._rafId = requestAnimationFrame(this._tick);
        const remaining = Math.max(0, this._duration - this._elapsed);
        this._timerId = window.setTimeout(this._dismiss, remaining);
      };

      this._pause = () => {
        if (!this._autoclose || this._paused) return;
        this._paused = true;
        if (this._startTs != null) {
          this._elapsed += performance.now() - this._startTs;
        }
        this._clearTimers();
      };

      this._resume = () => {
        if (!this._autoclose || !this._paused) return;
        this._paused = false;
        this._start();
      };

      this._clearRaf = () => {
        if (this._rafId != null) {
          cancelAnimationFrame(this._rafId);
          this._rafId = null;
        }
      };

      this._clearTimers = () => {
        this._clearRaf();
        if (this._timerId != null) {
          clearTimeout(this._timerId);
          this._timerId = null;
        }
      };

      this._onMouseEnter = () => this._pause();
      this._onMouseLeave = () => this._resume();
      this.el.addEventListener("mouseenter", this._onMouseEnter);
      this.el.addEventListener("mouseleave", this._onMouseLeave);

      this._setProgress(1);
      this._start();
    },
    destroyed() {
      this.el.removeEventListener("mouseenter", this._onMouseEnter);
      this.el.removeEventListener("mouseleave", this._onMouseLeave);
      this._clearTimers?.();
    }
  },
 AdminSidebar: {
  mounted() {
    const root = document.documentElement;
    const overlay = document.getElementById("sidebar-overlay");
    const chevron = this.el.querySelector(".hero-chevron-right");
    this._sidebarTooltipEl = null;
    this._tooltipTargets = [];
    const transitionMs = () => {
      const raw = getComputedStyle(this.el).transitionDuration || "0s";
      return raw
        .split(",")
        .map((part) => part.trim())
        .map((part) => (part.endsWith("ms") ? parseFloat(part) : parseFloat(part) * 1000))
        .filter((n) => !Number.isNaN(n))
        .reduce((max, n) => Math.max(max, n), 0);
    };

    const syncChevron = () => {
      if (!chevron) return;
      const isCollapsed = root.hasAttribute("data-sidebar-collapsed");
      chevron.classList.toggle("rotate-180", !isCollapsed);
      chevron.classList.toggle("rotate-0", isCollapsed);
    };

    const ensureFloatingTooltip = () => {
      if (this._sidebarTooltipEl) return this._sidebarTooltipEl;
      const tip = document.createElement("div");
      tip.className = "sidebar-tooltip-floating";
      document.body.appendChild(tip);
      this._sidebarTooltipEl = tip;
      return tip;
    };

    const hideFloatingTooltip = () => {
      if (!this._sidebarTooltipEl) return;
      this._sidebarTooltipEl.classList.remove("visible");
    };

    const showFloatingTooltip = (event) => {
      const target = event.currentTarget;
      const label = target?.dataset?.tooltip;
      if (!label) return;
      if (!root.hasAttribute("data-sidebar-collapsed")) return;
      if (window.innerWidth < 1024) return;

      const tooltip = ensureFloatingTooltip();
      const rect = target.getBoundingClientRect();
      tooltip.textContent = label;
      tooltip.style.left = `${rect.right + 8}px`;
      tooltip.style.top = `${rect.top + rect.height / 2}px`;
      tooltip.classList.add("visible");
    };

    // Restore persisted collapsed state on each mount
    if (localStorage.getItem("sidebar-collapsed") === "true") {
      root.setAttribute("data-sidebar-collapsed", "true");
    } else {
      root.removeAttribute("data-sidebar-collapsed");
    }
    // Set initial direction without animation to avoid a rotate flash on page load
    if (chevron) {
      const originalTransition = chevron.style.transition;
      chevron.style.transition = "none";
      syncChevron();
      requestAnimationFrame(() => {
        chevron.style.transition = originalTransition;
      });
    } else {
      syncChevron();
    }

    this._onToggleSidebar = () => {
      const isCollapsed = root.hasAttribute("data-sidebar-collapsed");
      if (isCollapsed) {
        this.el.classList.add("sidebar-expanding");
        clearTimeout(this._expandDoneTimer);
        root.removeAttribute("data-sidebar-collapsed");
        localStorage.setItem("sidebar-collapsed", "false");
        this._expandDoneTimer = setTimeout(() => {
          this.el.classList.remove("sidebar-expanding");
        }, Math.min(180, transitionMs() * 0.4));
      } else {
        this.el.classList.remove("sidebar-expanding");
        root.setAttribute("data-sidebar-collapsed", "true");
        localStorage.setItem("sidebar-collapsed", "true");
      }
      syncChevron();
      this._hideFloatingTooltip?.();
    };

    this._onCloseMobileSidebar = () => {
      this.el.classList.add("-translate-x-full");
      this.el.classList.remove("translate-x-0");
      overlay?.classList.add("hidden");
    };

    this._onOpenMobileSidebar = () => {
      this.el.classList.remove("-translate-x-full");
      this.el.classList.add("translate-x-0");
      overlay?.classList.remove("hidden");
    };

    this._onOverlayClick = () => {
      window.dispatchEvent(new Event("admin:close-mobile-sidebar"));
    };

    window.addEventListener("admin:toggle-sidebar", this._onToggleSidebar);
    window.addEventListener("admin:close-mobile-sidebar", this._onCloseMobileSidebar);
    window.addEventListener("admin:open-mobile-sidebar", this._onOpenMobileSidebar);
    overlay?.addEventListener("click", this._onOverlayClick);

    this._showFloatingTooltip = showFloatingTooltip;
    this._hideFloatingTooltip = hideFloatingTooltip;
    this._tooltipTargets = Array.from(this.el.querySelectorAll("[data-tooltip]"));
    this._tooltipTargets.forEach((node) => {
      node.addEventListener("mouseenter", this._showFloatingTooltip);
      node.addEventListener("mouseleave", this._hideFloatingTooltip);
      node.addEventListener("blur", this._hideFloatingTooltip, true);
    });
    window.addEventListener("scroll", this._hideFloatingTooltip, true);
  },

  destroyed() {
    const overlay = document.getElementById("sidebar-overlay");
    clearTimeout(this._expandDoneTimer);

    window.removeEventListener("admin:toggle-sidebar", this._onToggleSidebar);
    window.removeEventListener("admin:close-mobile-sidebar", this._onCloseMobileSidebar);
    window.removeEventListener("admin:open-mobile-sidebar", this._onOpenMobileSidebar);
    overlay?.removeEventListener("click", this._onOverlayClick);

    this._tooltipTargets?.forEach((node) => {
      node.removeEventListener("mouseenter", this._showFloatingTooltip);
      node.removeEventListener("mouseleave", this._hideFloatingTooltip);
      node.removeEventListener("blur", this._hideFloatingTooltip, true);
    });
    window.removeEventListener("scroll", this._hideFloatingTooltip, true);
    this._sidebarTooltipEl?.remove();
    this._sidebarTooltipEl = null;
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
