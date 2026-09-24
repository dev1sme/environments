!(function () {
    "use strict";
    var t = "env-badge";
    if (!document.getElementById(t)) {
        var e = "dev",
            n = "#9F000C",
            o = "#FFFFFF",
            r = 80,
            i = 11.5,
            a = 0.85,
            c =
                "'Arial Narrow','Roboto Condensed','Helvetica Neue Condensed','Liberation Sans Narrow','DIN Condensed',Haettenschweiler,Impact,Arial,sans-serif",
            d =
                document.currentScript ||
                document.querySelector('script[src*="dev.js"]'),
            s = (function (t) {
                var e = {};
                if (!t || !t.getAttribute("src")) return e;
                var n = t.getAttribute("src").split("?")[1];
                return n
                    ? (n.split("&").forEach(function (t) {
                          if (t) {
                              var n = t.indexOf("="),
                                  o = decodeURIComponent(
                                      n < 0 ? t : t.slice(0, n),
                                  ).replace(/-/g, ""),
                                  r =
                                      n < 0
                                          ? ""
                                          : decodeURIComponent(
                                                t
                                                    .slice(n + 1)
                                                    .replace(/\+/g, " "),
                                            );
                              e[o.toLowerCase()] = r;
                          }
                      }),
                      e)
                    : e;
            })(d),
            l = String(b("type", e)).toLowerCase(),
            u =
                {
                    dev: { text: "THOMSON", color: "#9F000C" },
                    test: { text: "TEST ENV", color: "#9F000C" },
                    stg: { text: "STAGING", color: "#9F000C" },
                    staging: { text: "STAGING", color: "#9F000C" },
                    replace: { text: "REPLACE", color: "#9F000C" },
                }[l] || {},
            g = String(b("text", u.text || l.toUpperCase())),
            m = b("color", u.color || n),
            p = b("text-color", o),
            h = A(b("size", r), r),
            f = A(b("font-size", i), i),
            x = A(b("condense", a), a),
            v = b("font", c),
            C = Math.min(
                (function (t) {
                    try {
                        var e = document
                            .createElement("canvas")
                            .getContext("2d");
                        e.font = "700 " + f + "px " + v;
                        var n = e.measureText(t).width;
                        if (n > 0) return n;
                    } catch (t) {}
                    return t.length * f * 0.55;
                })(g) * x,
                41,
            ),
            w =
                '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M48 48L0 0H27L48 21V48Z" fill="' +
                L(m) +
                '"/><text x="0" y="0" dy="0.35em" text-anchor="middle" transform="translate(30 16.5) rotate(45)" textLength="' +
                C.toFixed(2) +
                '" lengthAdjust="spacingAndGlyphs" fill="' +
                L(p) +
                '" font-family="' +
                L(v) +
                '" font-size="' +
                f +
                '" font-weight="700" font-stretch="condensed">' +
                L(g) +
                "</text></svg>",
            F = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(w),
            y = document.createElement("div");
        ((y.id = t),
            y.setAttribute("aria-hidden", "true"),
            (y.style.cssText = [
                "position:fixed",
                "right:0",
                "top:0",
                "z-index:1000001",
                "mix-blend-mode:normal",
                "pointer-events:none",
                "width:" + h + "px",
                "height:" + h + "px",
                "line-height:0",
                // Collapsing slides the ribbon diagonally into the corner.
                "transition:" + (M() ? "none" : "transform .35s cubic-bezier(.2,.8,.2,1)"),
            ].join(";")));
        var E = document.createElement("img");
        ((E.src = F),
            (E.alt = g),
            (E.title = "Bấm để thu gọn / mở"),
            // Only the ribbon itself takes clicks (clip-path follows the SVG band);
            // the transparent rest of the square stays click-through.
            (E.style.cssText =
                "display:block;width:100%;height:100%;pointer-events:auto;cursor:pointer;" +
                "clip-path:polygon(0 0,56.25% 0,100% 43.75%,100% 100%)"),
            E.addEventListener("click", function () {
                S(!P(), !0);
            }),
            y.appendChild(E),
            S("1" === k("get"), !1),
            document.body
                ? I()
                : document.addEventListener("DOMContentLoaded", I));
    }
    // Collapsed: pushed 18/48 of the viewBox towards the corner, leaving a small
    // tip of the band on screen to click and bring it back.
    function S(t, e) {
        ((y.style.transform = t ? "translate(37.5%,-37.5%)" : "none"),
            (y.dataset.collapsed = t ? "1" : "0"),
            e && k("set", t ? "1" : "0"));
    }
    function P() {
        return "1" === y.dataset.collapsed;
    }
    function M() {
        try {
            return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        } catch (t) {
            return !1;
        }
    }
    // localStorage can throw (privacy mode, sandboxed iframes); without it the
    // badge just starts expanded on every load.
    function k(t, e) {
        try {
            if ("get" === t) return localStorage.getItem("env-badge-collapsed");
            localStorage.setItem("env-badge-collapsed", e);
        } catch (t) {}
        return null;
    }
    function b(t, e) {
        var n = d && d.getAttribute ? d.getAttribute("data-" + t) : null,
            o =
                null != n && "" !== n
                    ? n
                    : s[t.replace(/-/g, "").toLowerCase()];
        return null != o && "" !== o ? o : e;
    }
    function A(t, e) {
        var n = parseFloat(t);
        return isFinite(n) ? n : e;
    }
    function L(t) {
        return String(t).replace(/[&<>"']/g, function (t) {
            return {
                "&": "&amp;",
                "<": "&lt;",
                ">": "&gt;",
                '"': "&quot;",
                "'": "&apos;",
            }[t];
        });
    }
    function I() {
        document.getElementById(t) ||
            (document.body || document.documentElement).appendChild(y);
    }
})();
