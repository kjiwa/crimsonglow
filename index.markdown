---
layout: home
title: Home
---

{%- for post in site.posts %}
* {{ post.date | date: "%Y-%m" }} [{{ post.title }}]({{ site.baseurl}}{{ post.url }})
{%- endfor %}

Reach me at [kjiwa@crimsonglow.ca](mailto:kjiwa@crimsonglow.ca).

<div class="home-links">
  <a href="https://github.com/kjiwa"><i class="fa-brands fa-github"></i></a>
  <a href="https://instagram.com/kjiwa"><i class="fa-brands fa-instagram"></i></a>
  <a href="https://www.youtube.com/user/kamiljiwa"><i class="fa-brands fa-youtube"></i></a>
</div>
