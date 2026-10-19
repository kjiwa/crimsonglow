---
layout: null
---
// Pre-2024 the site routed in JS as /~kjiwa/#/slug, and old inbound links (e.g. a gist
// linking to #/exploiting-apache-james) still use that form. Fragments never reach the
// server, so a 301 can't fix this — this recovers the reader, not the link equity.
(function () {
  var slug = location.hash.replace(/^#\/?/, "").replace(/\/$/, "");
  if (!slug) return;
  var legacy = {
{%- for entry in site.data.redirects %}
    {{ entry[0] | split: "/" | last | remove: ".html" | jsonify }}: {{ entry[1] | jsonify }}{% unless forloop.last %},{% endunless %}
{%- endfor %}
  };
  if (legacy[slug]) {
    location.replace(legacy[slug]);
    return;
  }
  var urls = [{% for post in site.posts %}{{ post.url | jsonify }}{% unless forloop.last %}, {% endunless %}{% endfor %}];
  var match = urls.find(function (url) {
    var name = url.split("/").pop().replace(/\.html$/, "");
    return name === slug || name.indexOf(slug) === 0;
  });
  if (match) location.replace(match);
})();
