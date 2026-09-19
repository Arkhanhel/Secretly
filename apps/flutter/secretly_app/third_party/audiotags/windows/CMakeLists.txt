# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "audiotags")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "audiotags_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "audiotags_plugin.cpp"
  "audiotags_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/audiotags/audiotags_plugin_c_api.h"
  "audiotags_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# 🔴 ПРАВКА SECRETLY: ГОТОВУЮ БИБЛИОТЕКУ БОЛЬШЕ НЕ КАЧАЕМ.
#
# Здесь скачивался windows.tar.gz с чужого выпуска на GitHub — и распаковка
# падала, потому что Flutter подставляет плагины ССЫЛКАМИ, а CMake не
# распаковывает архив по ссылке. Но чинить было нечего: рядом, в
# rust_builder, cargokit собирает ТОТ ЖЕ крейт из исходников, лежащих в этом
# же дереве, и делает ровно тот же audiotags.dll. Скачанный двоичный файл был
# вторым таким же — и именно он, а не наш исходник, попал бы в сборку.
#
# Для переписки, которую будут проверять построчно, это важнее удобства:
# теперь под Windows в приложение идёт только то, что собрано из исходников
# репозитория.

# Библиотеку приносит rust_lib_audiotags (cargokit), здесь добавлять нечего.
set(audiotags_bundled_libraries
  ""
  PARENT_SCOPE
)
