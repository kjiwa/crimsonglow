---
title: Introduction to KDE Programming
---
## Introduction

### Motivation

The information presented within stems from my experiences developing for the KDE platform. I've found that it is difficult to find relevant documentation for KDE components such as DCOP, KConfig, and icon themes. The situation becomes increasingly dire for less common uses of these components. Often one must resort to source code for other KDE projects to see how some of these components are to be used. I hope to address this and guide a new KDE developer through the different components available to them.

### Applications vs Applets

A KDE application conventionally consists of a main window with a menu bar and toolbars, for example, Konqueror and JuK. A user may explicitly invoke it by executing the associated binary. A KDE panel applet is similar in structure to a KDE application but it is implicitly invoked through the Kicker, the KDE panel, and runs from within it.

Very simply, the technical distinction between an application and an applet is in the use of KApplication versus KPanelApplet as a base class for your program. Simply substituting one base class for the other, however, will not transform your program into the other. There are differences in the project structure affecting things such as the build process and entry points. The technical aspects will be covered in subsequent sections.

## Requirements

### Prerequisites

In order to compile and run the programs used herein you must have a working GNU/Linux environment with the following packages:

* kdelibs, kdelibs-dev[el] (3.2+)
* gcc, g++, make
* autoconf, automake, libtool

### Expected Background

The reader ought to have experience developing with C++ in a Linux environment. Basic knowledge of Qt and KDE is beneficial.

## The Basics

### Application

The basic structure for a KDE application contains the application class, subclassed from KApplication, and an entry point.

<div class="caption">application.cpp</div>

{% highlight cpp %}
#include <kaboutdata.h>
#include <kapplication.h>
#include <kcmdlineargs.h>
#include <klocale.h>

class Application : public KApplication { };

int main(int argc, char* argv[]) {
  KAboutData about("application", I18N_NOOP("Application"), "0.1", I18N_NOOP("Application"), KAboutData::License_GPL_V2);
  KCmdLineArgs::init(argc, argv, &about);
  Application a;
  return a.exec();
}
{% endhighlight %}

This program creates a new KDE application with an event loop. The program is created as a binary with int main(int, char* []) as its entry point. No further actions are taken.

To build the application by hand, the following commands may be used:

{% highlight bash %}
$ g++ -I/usr/include/qt3 -I/usr/include/kde -c -o application.o ./application.cpp
$ g++ -L/usr/lib/kde -lkdeui -o application application.o
{% endhighlight %}

### Applet

The basic structure for a KDE applet is similar to that for applications. The code base contains the applet class, subclassed from KPanelApplet, and an entry point.

<div class="caption">applet.cpp</div>

{% highlight cpp %}
#include <kglobal.h>
#include <klocale.h>
#include <kpanelapplet.h>

class Applet : public KPanelApplet { };

extern "C" {
  KPanelApplet* init(QWidget* parent, const QString& configFile) {
    int actions = 0;
    KGlobal::locale()->insertCatalogue("applet");
    return new Applet(configFile, KPanelApplet::Normal, actions, parent, "applet");
  }}
{% endhighlight %}

Notice that while the main class has a similar structure to the application, the entry point differs significantly. The applet is not compiled to a binary program and it cannot be invoked with main(). Instead, the applet is compiled to a shared object with init() as an entry point.

A class and an entry point are not enough to load the applet. The KDE Kicker and Panel Applet Proxy rely on the presence of a .desktop file which contains information about the applet and how to load it. The example .desktop file tells the invoking application (e.g. Kicker, Applet Proxy) that the code the our applet is available in the libapplet object.

<div class="caption">applet.desktop</div>

{% highlight cfg %}
[Desktop Entry]
Encoding=UTF-8
Comment=An Example Applet
Name=Applet
X-KDE-Library=libapplet
{% endhighlight %}

Here we define a name and description for the applet, "Applet" and "An Example Applet", respectively. The X-KDE-Library setting tells the invoking application which library the applet has been compiled to, libapplet.so in this case.

Tip: Use the Panel Applet Proxy to run the applet from a console to view debugging output. e.g.

{% highlight bash %}
$ appletproxy /usr/share/apps/kicker/applets/applet.desktop
{% endhighlight %}

### User Interface

Our user interface (UI) will be implemented as a widget and therefore inherits from QWidget. Within the widget is also where the program logic should be implemented. Placing the UI within the widget increases code reusability, although it is not incorrect to directly implement it within the application or applet.

<div class="caption">widget.h</div>

{% highlight cpp %}
#include <qwidget.h>

class Widget : public QWidget { };
{% endhighlight %}

We can load the widget by creating a new instance of the widget and displaying it from anywhere within the code.

{% highlight cpp %}
#include "widget.h"

{
  ...
  Widget* pWidget = new Widget(this);
  pWidget->show();
  ...
}
 {% endhighlight %}

## Settings

With the release of KDE 3.2, KConfig XT has been adopted as the official configuration framework for KDE and KDE programs. For each configuration file, two files are required: a .kcfg file containing the configuration structure and a .kcfgc file containing code generation options.

The .kcfg file contains XML describing the settings data. Conventionally it should have the same base name as the target being compiled (i.e. for libapplet.la use libapplet_la.kcfg and for application use application.kcfg).

<div class="caption">application.kcfg</div>

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE kcfg SYSTEM "http://www.kde.org/standards/kcfg/1.0/kcfg.dtd">
<kcfg>
  <kcfgfile name="apprc" />
  <group name="General">
    <entry name="icon" type="String">
      <label>The program icon.</label>
      <default>kate</default>
    </entry>
  </group>
</kcfg>
{% endhighlight %}

The example settings shown in figure 6 define one option, stored as a string, called icon. The save location is defined by the kcfgfile tag, "apprc" in this case.

The .kcfgc file is an ini file containing code generation options. Values for File and ClassName are required. These options tell the settings compiler which file the settings data has been defined in and what the name of the generated class will be, e.g. settings.kcfgc.

<div class="caption">settings.kcfgc</div>

{% highlight cfg %}
File=application.kcfg
ClassName=Settings
{% endhighlight %}

Other available options include Inherits, MemberVariables, Mutators NameSpace, and Singleton. The use of the Mutators option is particularly useful if options data may change.

In order to use the settings data, the files must be compiled by the kconfig_compiler program. e.g.

{% highlight bash %}
$ kconfig_compiler application.kcfg settings.kcfgc
{% endhighlight %}

The class generated in the example is output to settings.h and has the following interface:

<div class="caption">settings.h</div>

{% highlight cpp %}
#include <kconfigskeleton.h>

class Settings : public KConfigSkeleton {
public:
  Settings();
  ~Settings();

  QString icon() const;

protected:
  QString mIcon;
};
{% endhighlight %}

Note that we need not explicitly load or save the settings; KConfig XT takes care of this for us and stores them in $KDE_HOME/.kde/share/config.

## Interprocess Communication

The Desktop Communication Protocol (DCOP) was designed to achieve interprocess communication (IPC) between KDE programs. To use DCOP, an interface needs to be defined for the program. Doing so exposes a set of functions to the DCOP server.

<div class="caption">widgetinterface.h</div>

{% highlight cpp %}
#include <dcopobject.h>

class WidgetInterface : virtual public DCOPObject {
  K_DCOP

k_dcop:
  virtual QString icon() const=0;
  virtual void quit()=0;
};
{% endhighlight %}

The implementation is straightforward. The name of the interface is set as a parameter to the DCOPObject base class.

<div class="caption">widget.cpp</div>

{% highlight cpp %}
#include "settings.h"
#include "widgetinterface.h"
#include <dcopclient.h>
#include <kglobal.h>
#include <qwidget.h>

class Widget : public QWidget, public WidgetInterface {
public:
  Widget(QWidget* parent=0, const char* name=0) : QWidget(parent, name), DCOPObject("WidgetInterface") { }

  QString icon() const {
    Settings s;
    return s.icon();
  }

  void quit() {
    kapp->quit();
  }
};
{% endhighlight %}

The next step is to establish a connection with the DCOP server. This step is typically done once by the main application (e.g. within Application() or Applet()). Any interfaces which have been implemented will automatically become available.

{% highlight cpp %}
#include <dcopclient.h>

{
  ...
  DCOPClient client;
  client.registerAs("application", false);
  ...
}
{% endhighlight %}

Now, we have the following functions available to DCOP:

{% highlight cpp %}
application.WidgetInterface.icon()
application.WidgetInterface.quit()
{% endhighlight %}

We can use the DCOP client to call these functions from within the program.

{% highlight cpp %}
#include <dcopclient.h>
#include <qbytearray.h>
#include <qdatastream.h>
#include <qcstring.h>

QByteArray data, replyData;
QCString replyType;

DCOPClient client;
if (client.call("application", "WidgetInterface", "icon", data, replyType, replyData)) {
  if (replyType == "QString") {
    QDataStream reply(replyData, IO_ReadOnly);
    QString result;
    reply >> result;
  }
}
{% endhighlight %}

A DCOP interface is also an effective debugging tool. Tools such as dcop and kdcop allow execution and analysis of available DCOP interfaces. e.g.

{% highlight bash %}
$ dcop application WidgetInterface icon
{% endhighlight %}

## Widgets

### KMainWindow

Typically applications use dialogs as their main widget. KDE provides the KMainWindow widget to build a main window from.

<div class="caption">widget.cpp</div>

{% highlight cpp %}
#include <kmainwindow.h>

class Widget : public KMainWindow { };
{% endhighlight %}

### QLabel

Applets do not typically use dialogs as their main widget. Instead buttons, labels, sliders, and many others are commonly used.

<div class="caption">widget.cpp</div>

{% highlight cpp %}
#include <kicontheme.h>
#include <qlabel.h>

class Widget : public QLabel {
public:
  Widget(QWidget* parent=0, const char* name=0) : QLabel(parent, name) {
    setAlignment(Qt::AlignHCenter | Qt::AlignVCenter);
    Settings s;
    setPixmap(SmallIcon(s.icon()));
  }
};
{% endhighlight %}

### KConfigDialog

KConfigDialog is a type of dialog that has been customized for displaying settings. If the KConfig XT framework is being used, then our generated class to be defined as a singleton. A widget with the widget names corresponding to the names of the settings, prefixed with kcfg_, must be designed for use with the dialog. For example, a QLabel for the icon setting would be named kcfg_icon.

<div class="caption">widget.cpp</div>

{% highlight cpp %}
#include "settings.h"
#include "settingswidget.h"
#include <kconfigdialog.h>
#include <klocale.h>
#include <qwidget.h>

class Widget : public QWidget {
public:
  void preferences() {
    if (KConfigDialog::showDialog("settings")) {
      return;
    }

    KConfigDialog* pDialog = new KConfigDialog(this, "settings", Settings::self());
    SettingsWidget* pWidget = new SettingsWidget(0, "General");
    pDialog->addPage(pWidget, i18n("General"), "general");
    pDialog->show();
  }
};
{% endhighlight %}

## Event Handlers

### Context Menu

A context menu event is received when the right mouse button is pressed on the widget. By default, this event is ignored. To display a menu, a QPopupMenu or a KPopupMenu must be implemented within the contextMenuEvent event handler.

<div class="caption">widget.cpp</div>

{% highlight cpp %}
#include <dcopclient.h>
#include <kglobal.h>
#include <kicontheme.h>
#include <klocale.h>
#include <kpopupmenu.h>
#include <qwidget.h>

class Widget : public QWidget {
  Q_OBJECT

protected:
  void contextMenuEvent(QContextMenuEvent*) {
    KPopupMenu menu(this);
    menu.insertTitle(i18n("My Menu"));
    menu.insertItem(i18n("Menu Item"));
    menu.insertSeparator();
    menu.insertItem(SmallIcon("exit"), i18n("&Quit"), this, SLOT(quit()));
    menu.exec();
  }

private slots:
  void quit() {
    kapp->quit();
  }
};
{% endhighlight %}

The KHelpMenu object may be of interest. It provides a standard KDE help menu with various dialogs and links to help documentation and is easily embedded into the menu.

{% highlight cpp %}
{
  ...
  KAboutData about("application", I18N_NOOP("Application"), "0.1", I18N_NOOP("Application"), KAboutData::License_GPL_V2);
  KHelpMenu* pHelp = new KHelpMenu(this, &about, false);
  menu.insertItem(i18n("&Help"), pHelp->menu());
  ...
}
{% endhighlight %}

### Mouse Press

Mouse press events are received whenever the widget is clicked upon, whether it be with the left, middle, or right mouse buttons. These events may be captured from within the mousePressEvent event handler. Note that there is an overlap between the mouse press event and the context menu event when the right mouse button is pressed.

<div class="caption">widget.cpp</div>

{% highlight cpp %}
#include <qwidget.h>
#include <qevent.h>

class Widget : public QWidget {
protected:
  void mousePressEvent(QMousePressEvent* e) {
    if (e->button() == Qt::LeftButton) {
    }
  }
};
{% endhighlight %}

### Resize

As with the context menu and mouse press events, the resize event is handled by the resizeEvent() function. If an icon is displayed it may be resized by using the KDE icon theme functions.

{% highlight cpp %}
#include <kicontheme.h>
#include <qevent.h>
#include <qwidget.h>

class Widget : public QLabel {
public:
  Widget(QWidget* parent=0, const char* name=0) : QLabel(parent, name) {
    setAlignment(Qt::AlignHCenter | Qt::AlignVCenter);
  }

protected:
  void resizeEvent(QResizeEvent* e) {
    int h = e->size().height();
    int w = e->size().width();
    int size = (h > w) ? h : w;
    setPixmap(SmallIcon(Settings::icon(), size));
  }
};
{% endhighlight %}

## References

* Qt 3.3.3 API Reference. Trolltech AS. 10 September 2004 ([http://doc.trolltech.com/3.3/index.html](http://doc.trolltech.com/3.3/index.html)).
* KDE 3.3.0 API Reference. KDE e.V. 8 September 2004 (<http://developer.kde.org/documentation/library/3.3-api/index.html>).
* Using KConfig XT. KDE e.V and Zack Rusin. 17 September 2004 (<http://developer.kde.org/documentation/tutorials/kconfigxt/kconfigxt.html>).

## Acknowledgements

I would like to express my gratitude to Jeff Tranter (<jefft@xandros.com>) and the Xandros Corporation for introducing me to the world of KDE development. Without them this document would not have been possible.

Thanks also to Frerich Raabe (<raabe@kde.org>) for his suggestions in improving the code examples and explanations.
