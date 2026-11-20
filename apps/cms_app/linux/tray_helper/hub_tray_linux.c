// Mini helper nativo de bandeja do sistema para Linux (Ayatana AppIndicator3 + GTK3).
// Não cria janela visível nem contexto OpenGL/EGL/NVIDIA (~6-10 MB PSS).
// Protocolo NDJSON sobre stdin/stdout; encerra automaticamente ao detectar EOF em stdin.

#include <glib.h>
#include <gtk/gtk.h>
#include <libayatana-appindicator/app-indicator.h>
#include <stdio.h>
#include <string.h>

static GtkWidget *g_status_item = NULL;
static AppIndicator *g_indicator = NULL;

static void emit_action(const char *action) {
  fprintf(stdout, "{\"event\":\"tray\",\"action\":\"%s\"}\n", action);
  fflush(stdout);
}

static void on_open_cms(GtkMenuItem *item, gpointer user_data) {
  (void)item;
  (void)user_data;
  emit_action("open_cms");
}

static void on_open_search(GtkMenuItem *item, gpointer user_data) {
  (void)item;
  (void)user_data;
  emit_action("open_search");
}

static void on_publish(GtkMenuItem *item, gpointer user_data) {
  (void)item;
  (void)user_data;
  emit_action("publish");
}

static void on_reconnect(GtkMenuItem *item, gpointer user_data) {
  (void)item;
  (void)user_data;
  emit_action("reconnect");
}

static void on_pomodoro(GtkMenuItem *item, gpointer user_data) {
  (void)item;
  (void)user_data;
  emit_action("toggle_pomodoro");
}

static void on_quit(GtkMenuItem *item, gpointer user_data) {
  (void)item;
  (void)user_data;
  emit_action("quit");
  gtk_main_quit();
}

static void update_status_label(const char *state) {
  if (!g_status_item) return;
  if (strstr(state, "connected") != NULL && strstr(state, "disconnected") == NULL) {
    gtk_menu_item_set_label(GTK_MENU_ITEM(g_status_item), "● Broker: Conectado");
  } else if (strstr(state, "connecting") != NULL) {
    gtk_menu_item_set_label(GTK_MENU_ITEM(g_status_item), "◐ Broker: Conectando...");
  } else {
    gtk_menu_item_set_label(GTK_MENU_ITEM(g_status_item), "○ Broker: Desconectado");
  }
}

static gboolean on_stdin_ready(GIOChannel *source, GIOCondition condition,
                               gpointer data) {
  (void)data;
  if (condition & (G_IO_HUP | G_IO_ERR | G_IO_NVAL)) {
    gtk_main_quit();
    return FALSE;
  }

  gchar *line = NULL;
  gsize len = 0;
  GError *err = NULL;
  GIOStatus st = g_io_channel_read_line(source, &line, &len, NULL, &err);
  if (err) {
    g_error_free(err);
  }
  if (st == G_IO_STATUS_EOF) {
    g_free(line);
    gtk_main_quit();
    return FALSE;
  }
  if (st == G_IO_STATUS_NORMAL && line != NULL) {
    if (strstr(line, "\"quit\"") != NULL) {
      g_free(line);
      gtk_main_quit();
      return FALSE;
    }
    if (strstr(line, "\"status\"") != NULL) {
      update_status_label(line);
    }
    g_free(line);
  }
  return TRUE;
}

int main(int argc, char *argv[]) {
  const char *icon_path = NULL;
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--icon") == 0 && i + 1 < argc) {
      icon_path = argv[++i];
    }
  }

  gtk_init(&argc, &argv);

  const char *icon_name = "hub-agent";
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  g_indicator = app_indicator_new("hub-agent-daemon", icon_name,
                                  APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
  G_GNUC_END_IGNORE_DEPRECATIONS
  if (icon_path != NULL && g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
    gchar *dir = g_path_get_dirname(icon_path);
    gchar *base = g_path_get_basename(icon_path);
    gchar *dot = strrchr(base, '.');
    if (dot != NULL) *dot = '\0';
    app_indicator_set_icon_theme_path(g_indicator, dir);
    app_indicator_set_icon_full(g_indicator, base, "Hub Agent");
    g_free(dir);
    g_free(base);
  }
  app_indicator_set_title(g_indicator, "Hub Agent");
  app_indicator_set_status(g_indicator, APP_INDICATOR_STATUS_ACTIVE);

  GtkWidget *menu = gtk_menu_new();

  g_status_item = gtk_menu_item_new_with_label("○ Broker: Desconectado");
  gtk_widget_set_sensitive(g_status_item, FALSE);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), g_status_item);

  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());

  GtkWidget *item_open = gtk_menu_item_new_with_label("Abrir CMS");
  g_signal_connect(item_open, "activate", G_CALLBACK(on_open_cms), NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_open);

  GtkWidget *item_search = gtk_menu_item_new_with_label("Busca Rápida (Spotlight)");
  g_signal_connect(item_search, "activate", G_CALLBACK(on_open_search), NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_search);

  GtkWidget *item_publish = gtk_menu_item_new_with_label("Publicar layout agora");
  g_signal_connect(item_publish, "activate", G_CALLBACK(on_publish), NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_publish);

  GtkWidget *item_reconnect = gtk_menu_item_new_with_label("Reconectar broker");
  g_signal_connect(item_reconnect, "activate", G_CALLBACK(on_reconnect), NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_reconnect);

  GtkWidget *item_pomo = gtk_menu_item_new_with_label("Pomodoro: Iniciar / Pausar");
  g_signal_connect(item_pomo, "activate", G_CALLBACK(on_pomodoro), NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_pomo);

  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());

  GtkWidget *item_quit = gtk_menu_item_new_with_label("Encerrar agente");
  g_signal_connect(item_quit, "activate", G_CALLBACK(on_quit), NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_quit);

  gtk_widget_show_all(menu);
  app_indicator_set_menu(g_indicator, GTK_MENU(menu));
  app_indicator_set_secondary_activate_target(g_indicator, item_open);

  GIOChannel *stdin_ch = g_io_channel_unix_new(fileno(stdin));
  g_io_channel_set_encoding(stdin_ch, NULL, NULL);
  g_io_add_watch(stdin_ch,
                 (GIOCondition)(G_IO_IN | G_IO_HUP | G_IO_ERR | G_IO_NVAL),
                 on_stdin_ready, NULL);

  gtk_main();

  g_io_channel_unref(stdin_ch);
  g_object_unref(g_indicator);
  return 0;
}
