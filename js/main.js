// Drafting-sheet chrome: zone-reference frame modelled on the AS1100 border
// convention (letters down the side, numbers across the top) used on Kye's
// own drawing sheets. The per-page "sheet" identity is carried by the
// title-block footer instead of a second fixed tag, to avoid two chrome
// elements competing for the same corner.
function injectSheetFrame() {
  const cols = ["8", "7", "6", "5", "4", "3", "2", "1"];
  const rows = ["F", "E", "D", "C", "B", "A"];

  const frame = document.createElement("div");
  frame.className = "sheet-frame";
  frame.setAttribute("aria-hidden", "true");
  frame.innerHTML = `
    <div class="sheet-frame__border"></div>
    <div class="sheet-frame__ticks-x">${cols.map((c) => `<span>${c}</span>`).join("")}</div>
    <div class="sheet-frame__ticks-y">${rows.map((r) => `<span>${r}</span>`).join("")}</div>
  `;
  document.body.appendChild(frame);
}

// Clicking a drawing or render enlarges it here rather than navigating to the
// PDF. The markup still points at the PDF, so without JS the link works as a
// plain download — the lightbox is the enhancement, not the requirement.
function initLightbox() {
  const triggers = document.querySelectorAll("[data-zoom]");
  if (!triggers.length) return;

  const box = document.createElement("div");
  box.className = "lightbox";
  box.setAttribute("role", "dialog");
  box.setAttribute("aria-modal", "true");
  box.setAttribute("aria-label", "Enlarged drawing");
  box.innerHTML = `
    <div class="lightbox__bar">
      <span class="lightbox__caption"></span>
      <span>
        <a class="lightbox__pdf" href="#" target="_blank" rel="noopener">Open PDF &nearr;</a>
        <button type="button" class="lightbox__close">Close &times;</button>
      </span>
    </div>
    <div class="lightbox__scroll"><img alt="" /></div>
  `;
  document.body.appendChild(box);

  const img = box.querySelector("img");
  const caption = box.querySelector(".lightbox__caption");
  const pdfLink = box.querySelector(".lightbox__pdf");
  const closeBtn = box.querySelector(".lightbox__close");
  let lastFocused = null;

  function open(trigger) {
    lastFocused = trigger;
    img.src = trigger.dataset.zoom;
    img.alt = trigger.dataset.zoomAlt || "";
    img.classList.remove("is-zoomed");
    caption.textContent = trigger.dataset.zoomCaption || "";

    const pdf = trigger.dataset.zoomPdf || trigger.getAttribute("href");
    if (pdf && pdf !== "#") {
      pdfLink.href = pdf;
      pdfLink.hidden = false;
    } else {
      pdfLink.hidden = true;
    }

    box.classList.add("is-open");
    document.body.classList.add("lightbox-open");
    closeBtn.focus();
  }

  function close() {
    box.classList.remove("is-open");
    document.body.classList.remove("lightbox-open");
    img.src = "";
    if (lastFocused) lastFocused.focus();
  }

  triggers.forEach((t) => {
    t.addEventListener("click", (e) => {
      e.preventDefault();
      open(t);
    });
  });

  closeBtn.addEventListener("click", close);
  box.addEventListener("click", (e) => {
    if (e.target === box || e.target.classList.contains("lightbox__scroll")) close();
  });
  img.addEventListener("click", () => img.classList.toggle("is-zoomed"));
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && box.classList.contains("is-open")) close();
  });
}

document.addEventListener("DOMContentLoaded", () => {
  injectSheetFrame();
  initLightbox();

  const toggle = document.querySelector(".nav-toggle");
  const links = document.querySelector(".nav-links");
  if (toggle && links) {
    toggle.addEventListener("click", () => {
      const open = links.classList.toggle("open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    links.querySelectorAll("a").forEach((a) =>
      a.addEventListener("click", () => links.classList.remove("open"))
    );
  }

  // Contact form — progressive enhancement. Without JS the form still does a
  // normal POST and Netlify serves its own thank-you page; this just keeps the
  // user on the page and reports the result inline.
  const form = document.querySelector("#contact-form");
  if (form) {
    const status = document.querySelector("#form-status");
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      // URL-encoded, not multipart: Netlify Forms only parses multipart for
      // forms that declare a file input, so FormData would post but never
      // register a submission.
      const data = new URLSearchParams(new FormData(form)).toString();
      status.textContent = "Sending…";
      status.removeAttribute("data-state");
      try {
        const res = await fetch(form.action, {
          method: "POST",
          body: data,
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
        });
        if (res.ok) {
          status.textContent = "Thanks — your message has been sent. I'll get back to you soon.";
          status.setAttribute("data-state", "success");
          form.reset();
        } else {
          throw new Error("Form submission failed");
        }
      } catch (err) {
        status.textContent =
          "Something went wrong sending that. Please email me directly instead.";
        status.setAttribute("data-state", "error");
      }
    });
  }
});
