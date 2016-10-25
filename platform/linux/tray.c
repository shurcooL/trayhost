#ifndef NATIVE_C
#define NATIVE_C

#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <string.h>
#include <libappindicator/app-indicator.h>

static const char *icon = NULL;
static size_t iconSize = 0;
static const char *menu_title = NULL;
static const char *url = NULL;
static GtkWidget *menu = NULL;
char tmpIconNameBuf[32];

// implemented in go
extern void tray_callback(int itemId);

// internal wrapper for go callback
void _tray_callback(GtkMenuItem *item, gpointer user_data)
{
  tray_callback(GPOINTER_TO_INT(user_data));
}

// TODO: Implement.
void display_notification(int id, const char* title, const char* body, struct image imageData, double duration)
{
}

//TODO:
void clear_menu_items(){}

// TODO: Implement.
struct clipboard_content get_clipboard_content()
{
  struct clipboard_content cc;
  return cc;
}

// TODO: Implement.
void set_clipboard_string(const char* cp)
{
}

void add_menu_item(int id, const char* title, int disabled) {
  GtkWidget *item = gtk_menu_item_new_with_label(title);
  if (disabled == TRUE) {
     gtk_widget_set_sensitive(item, FALSE);
  }
  g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_tray_callback), GINT_TO_POINTER(id));
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
}

void add_separator_item() {
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());
}

typedef void* (*app_indicator_new_fun)(const gchar*, const gchar*, AppIndicatorCategory);
typedef void* (*app_indicator_set_status_fun)(AppIndicator*, AppIndicatorStatus);
typedef void* (*app_indicator_set_attention_icon_full_fun) (AppIndicator*,  const gchar* ,const gchar*);
typedef void* (*app_indicator_set_menu_fun)(AppIndicator*,GtkMenu*);

void create_indicator(void *handle)
{
  app_indicator_new_fun                       app_indicator_new;
  app_indicator_set_status_fun                app_indicator_set_status;
  app_indicator_set_menu_fun                  app_indicator_set_menu;

  app_indicator_new = dlsym(handle, "app_indicator_new");
  app_indicator_set_status = dlsym(handle, "app_indicator_set_status");
  app_indicator_set_menu = dlsym(handle, "app_indicator_set_menu");

  // write icon to temp file, otherwise imposible to set in libappindicator
  int fd = -1;
  memset(tmpIconNameBuf, 0, sizeof(tmpIconNameBuf));
  strncpy(tmpIconNameBuf,"/tmp/storageguiicon-XXXXXX",26);
  fd = mkstemp(tmpIconNameBuf);

  if (fd > 0) {
    if(write(fd, icon, iconSize) == -1) {
      fprintf(stderr, "Failed to write icon data into temp file\n");
    }
  } else {
    fprintf(stderr, "Failed to create temp file for icon\n");
  }

  AppIndicator *indicator = app_indicator_new (menu_title,
                                 tmpIconNameBuf,
                                 APP_INDICATOR_CATEGORY_APPLICATION_STATUS);

  app_indicator_set_status (indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_menu (indicator, GTK_MENU (menu));
}

static void tray_icon_on_menu(GtkStatusIcon *status_icon, guint button, guint activate_time, gpointer user_data)
{
    gtk_menu_popup(GTK_MENU(menu), NULL, NULL, NULL, NULL, 0, gtk_get_current_event_time());
}

void create_status_icon()
{
    GError *error = NULL;
    GInputStream *stream = g_memory_input_stream_new_from_data(icon, iconSize, NULL);
    GdkPixbuf *pixbuf = gdk_pixbuf_new_from_stream(stream, NULL, &error);
    if (error)
        fprintf(stderr, "Unable to create PixBuf: %s\n", error->message);


    GtkStatusIcon *tray_icon = gtk_status_icon_new_from_pixbuf(pixbuf);
    g_signal_connect(G_OBJECT(tray_icon), "popup-menu", G_CALLBACK(tray_icon_on_menu), NULL);
    gtk_status_icon_set_tooltip_text(tray_icon, menu_title);
    gtk_status_icon_set_visible(tray_icon, TRUE);
}

void init(const char* title, struct image imageData)
{
    int argc = 0;
    char *argv[] = { "" };
    gtk_init(&argc, (char***)&argv);

    menu_title = title;
    icon = imageData.bytes;
    iconSize = imageData.length;
    menu = gtk_menu_new();
    void *handle;

    // check if system has libappindicator1 package
    handle = dlopen("libappindicator.so.1", RTLD_LAZY);
    if(!handle) {
      create_status_icon();
    } else {
      create_indicator(handle);
    }
}

void native_loop()
{
  gtk_widget_show_all(menu);
  gtk_main ();
}

void exit_loop()
{
  gtk_main_quit();
}


#endif // NATIVE_C
