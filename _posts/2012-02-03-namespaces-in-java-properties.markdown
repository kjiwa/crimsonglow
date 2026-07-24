---
layout: post
title: Namespaces in Java Properties
date: 2012-02-03
---
*This post originally appeared on [Optify's Lead Generation Blog](http://www.optify.net/marketing-technology/adding-namespaces-to-java-properties) on February 3, 2012.*

Many software systems support running in multiple runtime environments -- for example, development, staging, and production. Often, the software is written to be agnostic of its environment. Environment-specific settings are stored in configuration files such as config.common.properties, config.development.properties, etc. As the software becomes larger and more complex, the configuration files follow suit, making the system and runtime environment harder to understand and debug.

We have this challenge at Optify: our products include nearly 80 separate configuration files containing over 2 700 lines of property definitions. We wanted to improve our configuration management but we also did not want to introduce a solution that was highly intrusive to our code base. After some thought, we decided that a good solution would involve adding namespace support to Java's property file syntax.

To illustrate the concept, consider a use case common to most Java projects -- logging. In a development environment we might want verbose logs written to the console on stderr, while in production we might want only warnings and errors written to files that are rotated every hour. For example:

<div class="caption">log4j.development.properties</div>

{% highlight cfg %}
log4j.rootLogger=DEBUG, A1
log4j.appender.A1=org.apache.log4j.ConsoleAppender
log4j.appender.A1.layout=org.apache.log4j.PatternLayout
{% endhighlight %}

<div class="caption">log4j.production.properties</div>

{% highlight cfg %}
log4j.rootLogger=WARN, A1
log4j.appender.A1=org.apache.log4j.DailyRollingFileAppender
log4j.appender.A1.datePattern='.'yyyy-MM-dd-HH
log4j.appender.A1.file=application.log
log4j.appender.A1.layout=org.apache.log4j.PatternLayout
{% endhighlight %}

This results in 2 configuration files with 8 lines of property definitions.

In a namespace-aware world, our configuration might instead look like this:

<div class="caption">log4j.properties With Namespaces</div>

{% highlight cfg %}
*.log4j.rootLogger=DEBUG, A1
*.log4j.appender.A1=org.apache.log4j.ConsoleAppender
*.log4j.appender.A1.layout=org.apache.log4j.PatternLayout

production.log4j.rootLogger=WARN, A1
production.log4j.appender.A1=org.apache.log4j.DailyRollingFileAppender
production.log4j.appender.A1.datePattern='.'yyyy-MM-dd-HH
production.log4j.appender.A1.file=application.log
{% endhighlight %}

In this simple example, the namespacing gives us a small improvement, resulting in 1 configuration file and 7 lines of property definitions. Notice the "*" representing the default namespace from which all other namespaces inherit their values.

We decided to try integrating this solution with one of our services. The service had 4 configuration files with 195 lines of property definitions and 29 source files with nearly 6 000 lines of code. The results were promising, with a reduction of over 50% in lines of configuration. The footprint on our codebase was also minimal. Here is a diffstat:

{% highlight bash %}
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/config.development.properties |   55 ------
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/config.production.properties  |   52 ------
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/config.properties             |   80 ++++++++++
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/config.test.properties        |   43 -----
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/config.unittest.properties    |   45 -----
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.java                    |    9 +
6 files changed, 89 insertions(+), 195 deletions(-)
{% endhighlight %}

This is a pretty great improvement! We went from 195 lines of property definitions to 80 and changed less than 10 lines of code in 1 source file.

So what is actually required to enable namespace support? Our implementation was a rather simple extension of java.util.Properties. The base class does the hard work of loading and parsing the file, leaving us with the job of parsing the namespace and key. For backward compatibility, we ignored lines that do not appear to have an associated namespace, but you may wish to be more strict by throwing an exception.

<div class="caption">OptifyProperties.java</div>

{% highlight java %}
package com.optify.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.Iterator;
import java.util.Map;
import java.util.Properties;

public class OptifyProperties extends Properties {
  private static final long serialVersionUID = 1L;
  private static final String _DEFAULT_NAMESPACE = "*";

  private String _namespace;
  private Properties _properties;

  public OptifyProperties(String namespace) {
    super();
    _namespace = namespace;
    _properties = new Properties();
  }

  public OptifyProperties(String namespace, Properties p) {
    this(namespace);
    _copy(p);
  }

  public synchronized Object setProperty(String key, String value) {
    String[] parts = key.split("\\.");
    if (parts.length < 2)
      return null;

    String ns = parts[0];
    String k = key.substring(ns.length() + 1);

    if (ns.equals(_namespace)) {
      _properties.put(k, value);
      return put(k, value);
    }

    if (ns.equals(_DEFAULT_NAMESPACE) && !_properties.containsKey(k))
      return put(k, value);

    return null;
  }

  public synchronized void load(InputStream in) throws IOException {
    Properties p = new Properties();
    p.load(in);
    _copy(p);
  }

  private void _copy(Properties p) {
    Iterator i = p.entrySet().iterator();
    while (i.hasNext()) {
      Map.Entry entry = (Map.Entry) i.next();
      setProperty((String) entry.getKey(), (String) entry.getValue());
    }
  }
}
{% endhighlight %}

Once this file is available in our project, we can load our namespaced configuration files when our system initializes like so:

{% highlight java %}
InputStream in = getClass().getClassLoader().getResourceAsStream("log4j.properties");
Properties p = new OptifyProperties("production");
p.load(in);
{% endhighlight %}

We're excited to share our solution with the community. We have found it to be a lightweight and powerful extension of the native Java properties format and hope that others benefit from it as much as we have.
