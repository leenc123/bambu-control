#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Phosh/触摸设备上没有鼠标指针，gdk_display_get_primary_monitor() 会返回
// NULL（"primary" 按指针位置定义）。手机只有一块屏幕，直接取第 0 块。
static GdkMonitor* get_first_monitor() {
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr || gdk_display_get_n_monitors(display) < 1) {
    return nullptr;
  }
  return gdk_display_get_monitor(display, 0);
}

// Phosh 启动竞态：窗口首次 map 时 fullscreen 状态可能被丢弃
// （窗口停在工作区尺寸，顶部露出系统栏；锁屏/解锁后能铺满说明
// fullscreen 本身有效，只是启动时丢了请求）。map 后重发一次。
static void on_window_map(GtkWidget* widget, gpointer user_data) {
  gtk_window_fullscreen(GTK_WINDOW(widget));
}

// 延迟兜底：map 后 Phosh 若仍未应用全屏，1.2 秒后再补一次，并打印尺寸。
static gboolean fullscreen_later(gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  gtk_window_fullscreen(window);
  gint width = 0, height = 0;
  gtk_window_get_size(window, &width, &height);
  g_print("BAMBU-DEBUG: after-fullscreen window=%dx%d\n", width, height);
  return G_SOURCE_REMOVE;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  // 双保险：把 Flutter 视图尺寸强制为显示器输出尺寸。
  // Wayland 全屏下若 surface 尺寸与面板比例不符，合成器会等比缩放
  // 留黑边（如默认 1280x720 横屏 surface 在 720x1280 竖屏面板上）。
  GdkMonitor* monitor = get_first_monitor();
  if (monitor != nullptr) {
    GdkRectangle geometry;
    gdk_monitor_get_geometry(monitor, &geometry);
    gtk_widget_set_size_request(GTK_WIDGET(view), geometry.width,
                                geometry.height);
  }

  // 调试信息：打印窗口实际尺寸，确认是否等于面板尺寸。
  // 会出现在 ~/.cache/bambu_lab_app/autostart.log 里。
  gint width = 0, height = 0;
  gtk_window_get_size(window, &width, &height);
  g_print("BAMBU-DEBUG: window=%dx%d\n", width, height);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // 去掉标题栏（无边框窗口）。应用运行在手机/嵌入式 Linux 上，
  // 不需要系统装饰和顶部标题栏。
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_title(window, "");

  // 窗口默认尺寸 = 显示器逻辑尺寸（scale 2 下 720x1280 物理面板 = 360x640 逻辑）。
  // 不写死 1280x720：横屏默认尺寸在竖屏面板上会被等比缩放，留上下黑边。
  GdkMonitor* monitor = get_first_monitor();
  if (monitor != nullptr) {
    GdkRectangle geometry;
    gdk_monitor_get_geometry(monitor, &geometry);
    // 调试：GDK 上报的显示器逻辑尺寸与缩放（autostart.log 可查）。
    // 预期 720x1280 面板 + scale 2 = 360x640；若返回 1280x720 说明
    // GDK 给的是物理像素，需要按 scale 换算。
    g_print("BAMBU-DEBUG: monitor=%dx%d scale=%d\n", geometry.width,
            geometry.height, gdk_monitor_get_scale_factor(monitor));
    gtk_window_set_default_size(window, geometry.width, geometry.height);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);

  // Kiosk 模式：视图尺寸 = 显示器逻辑尺寸，首帧直接按面板尺寸渲染；
  // 再 fullscreen + show。若 Phosh 老版本 fullscreen 失效，窗口本身
  // 就是面板尺寸，仍然铺满（scale 2 下 720x1280 面板 = 360x640 逻辑）。
  {
    GdkMonitor* monitor =
        gdk_display_get_primary_monitor(gdk_display_get_default());
    if (monitor != nullptr) {
      GdkRectangle geometry;
      gdk_monitor_get_geometry(monitor, &geometry);
      gtk_widget_set_size_request(GTK_WIDGET(view), geometry.width,
                                  geometry.height);
    }
  }
  gtk_window_fullscreen(window);
  gtk_widget_show(GTK_WIDGET(window));

  // 启动竞态兜底：map 后重发 fullscreen + 1.2s 延迟补发。
  // 不依赖首帧时序，确保开机自启时也能最终铺满全屏。
  g_signal_connect(window, "map", G_CALLBACK(on_window_map), nullptr);
  g_timeout_add(1200, fullscreen_later, window);

  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
