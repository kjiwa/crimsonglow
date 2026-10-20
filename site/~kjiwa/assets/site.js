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
    var links = [];

    details.appendChild(el("summary", "", "On this page"));
    headings.forEach(function (heading) {
      var item = el("li");
      var link = el("a", "", headingLabel(heading));
      link.href = "#" + heading.id;
      item.appendChild(link);
      links.push(link);
      if (heading.tagName === "H3" && sub) {
        sub.appendChild(item);
        return;
      }
      root.appendChild(item);
      if (heading.tagName === "H2") {
        sub = el("ol");
        item.appendChild(sub);
      }
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
    return { node: details, links: links };
  }

  function trackSection(headings, links) {
    var active = -1;

    function activate(index) {
      if (index === active) return;
      active = index;
      links.forEach(function (link, i) {
        if (i === index) link.setAttribute("aria-current", "location");
        else link.removeAttribute("aria-current");
      });
    }

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          var index = headings.indexOf(entry.target);
          if (entry.isIntersecting) activate(index);
          else if (entry.boundingClientRect.top > 0) activate(index - 1);
        });
      },
      { rootMargin: "0px 0px -75% 0px" }
    );
    headings.forEach(function (heading) {
      observer.observe(heading);
    });
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
    var tocHeadings = headings.filter(function (heading) {
      return !heading.classList.contains("year");
    });
    if (!rail || tocHeadings.length < 3 || document.body.classList.contains("home")) return;
    var toc = buildToc(tocHeadings);
    rail.appendChild(toc.node);
    if ("IntersectionObserver" in window) trackSection(tocHeadings, toc.links);
  }

  main();
})();
