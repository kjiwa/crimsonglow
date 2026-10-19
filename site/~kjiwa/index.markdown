---
layout: home
title: Kamil Jiwa
---

Software and systems engineer. Notes on programming, systems, and security research,
collected here since 2004.

{%- for post in site.posts %}
* {{ post.date | date: "%Y-%m" }} [{{ post.title }}]({{ post.url }})
{%- endfor %}
{:.posts}

Reach me at [kjiwa@crimsonglow.ca](mailto:kjiwa@crimsonglow.ca).

<div class="home-links">
  {%- for profile in site.data.profiles %}
  <a href="{{ profile.url }}" rel="me" aria-label="{{ profile.name }}">
    <svg aria-hidden="true" focusable="false" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="{{ profile.icon }}"></path></svg>
  </a>
  {%- endfor %}
</div>
