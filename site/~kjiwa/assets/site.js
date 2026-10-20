(function () {
  "use strict";

  var WIDE = window.matchMedia("(min-width: 80rem)");

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text) node.textContent = text;
    return node;
  }

  function addHeadingAnchors(headings) {
    headings.forEach(function (heading) {
      var link = el("a", "heading-anchor", "#");
      link.href = "#" + heading.id;
      link.setAttribute("aria-label", "Link to " + heading.textContent);
      heading.appendChild(link);
    });
  }

  function addCopyButtons() {
    if (!navigator.clipboard) return;
    document.querySelectorAll(".content pre").forEach(function (pre) {
      var wrapper = el("div", "code");
      var button = el("button", "copy-button", "Copy");
      button.type = "button";
      button.setAttribute("aria-live", "polite");
      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);
      wrapper.appendChild(button);
      button.addEventListener("click", function () {
        navigator.clipboard.writeText(pre.textContent).then(function () {
          button.textContent = "Copied";
          window.setTimeout(function () {
            button.textContent = "Copy";
          }, 1500);
        });
      });
    });
  }

  function headingLabel(heading) {
    var copy = heading.cloneNode(true);
    copy.querySelectorAll(".heading-anchor").forEach(function (anchor) {
      anchor.remove();
    });
    return copy.textContent.trim();
  }

  function buildToc(headings) {
    var details = el("details", "toc");
    var root = el("ol");
    var sub = null;
    var group = null;
    var entries = [];

    details.appendChild(el("summary", "", "On this page"));
    headings.forEach(function (heading) {
      var item = el("li");
      var link = el("a", "", headingLabel(heading));
      link.href = "#" + heading.id;
      item.appendChild(link);
      if (heading.tagName === "H3" && sub) {
        sub.appendChild(item);
      } else {
        root.appendChild(item);
        group = item;
        if (heading.tagName === "H2") {
          sub = el("ol");
          item.appendChild(sub);
        }
      }
      entries.push({ heading: heading, link: link, group: group });
    });
    root.querySelectorAll("ol:empty").forEach(function (list) {
      list.remove();
    });
    details.appendChild(root);

    function syncOpen() {
      details.open = WIDE.matches;
    }
    syncOpen();
    WIDE.addEventListener("change", syncOpen);
    return { node: details, entries: entries };
  }

  // The current section is the last heading above a line a quarter of the way down the
  // viewport, so it follows the scroll position rather than the order of observer reports.
  // A click on an entry makes it current at once and holds it through the smooth scroll,
  // so the sections passed on the way do not open and close their sublists; the hold ends
  // when the reader scrolls, types or presses elsewhere.
  function trackSection(entries) {
    var active = -2;
    var queued = false;
    var pinned = false;

    function setActive(index) {
      if (index === active) return;
      active = index;
      entries.forEach(function (entry, i) {
        if (i === index) entry.link.setAttribute("aria-current", "location");
        else entry.link.removeAttribute("aria-current");
        entry.group.classList.toggle("current", index >= 0 && entry.group === entries[index].group);
      });
    }

    function update() {
      queued = false;
      if (pinned) return;
      var line = window.innerHeight * 0.25;
      var index = -1;
      entries.forEach(function (entry, i) {
        if (entry.heading.getBoundingClientRect().top <= line) index = i;
      });
      setActive(index);
    }

    function schedule() {
      if (queued) return;
      queued = true;
      window.requestAnimationFrame(update);
    }

    function release() {
      if (!pinned) return;
      pinned = false;
      schedule();
    }

    entries.forEach(function (entry, i) {
      entry.link.addEventListener("click", function () {
        pinned = true;
        setActive(i);
      });
    });
    ["wheel", "touchstart", "keydown", "pointerdown"].forEach(function (type) {
      window.addEventListener(type, release, { passive: true });
    });

    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    window.addEventListener("load", schedule);
    update();
  }

  function main() {
    var headings = Array.prototype.slice.call(
      document.querySelectorAll(".content h2[id], .content h3[id]")
    );
    addHeadingAnchors(
      Array.prototype.slice.call(
        document.querySelectorAll(".content h2[id], .content h3[id], .content h4[id]")
      )
    );
    addCopyButtons();

    var rail = document.querySelector(".toc-rail");
    if (!rail || headings.length < 3 || document.body.classList.contains("home")) return;
    var toc = buildToc(headings);
    rail.appendChild(toc.node);
    trackSection(toc.entries);
  }

  main();
})();
