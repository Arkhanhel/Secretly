# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(secretly_app LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "secretly_app")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Keep compatibility for third-party CMake projects (for example Firebase C++
# SDK shipped by FlutterFire) that still declare very old minimum CMake
# versions.
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# === FFmpegKit: заготовка вне дерева плагинов ===
#
# 🔴 ЗАЧЕМ. Flutter подставляет плагины ССЫЛКАМИ (flutter/ephemeral/
# .plugin_symlinks), а CMake отказывается распаковывать архив по ссылке:
# «Cannot extract through symlink» — защита libarchive от выхода за пределы
# каталога. Плагин ffmpeg_kit_flutter_new качает архив к себе, то есть через
# ссылку, и сборка Windows падает ещё до компиляции — у всех, а не только на
# сборочной машине.
#
# Поэтому достаём архив сюда, в каталог сборки: это настоящий путь, ссылок в
# нём нет. Плагину показываем готовую распаковку его же штатным способом —
# переменной FFMPEGKIT_LOCAL_DIR: по ней он КОПИРУЕТ файлы, а копирование
# через ссылку работает.
#
# Если скачать не вышло (нет сети), ничего не подставляем: плагин попробует
# сам и скажет об этом своими словами.
set(FFMPEGKIT_VARIANT "full-gpl")
set(FFMPEGKIT_RELEASE "8.0.0")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^([Aa][Rr][Mm]64|aarch64)$")
  set(FFMPEGKIT_CPU "aarch64")
else()
  set(FFMPEGKIT_CPU "x86_64")
endif()
set(FFMPEGKIT_STAGE "${CMAKE_BINARY_DIR}/ffmpeg-kit-prebuilt")
set(FFMPEGKIT_ARCHIVE_NAME
    "ffmpeg-kit-windows-${FFMPEGKIT_CPU}-${FFMPEGKIT_VARIANT}-${FFMPEGKIT_RELEASE}.zip")
set(FFMPEGKIT_ARCHIVE "${CMAKE_BINARY_DIR}/${FFMPEGKIT_ARCHIVE_NAME}")
if(NOT EXISTS "${FFMPEGKIT_STAGE}/bin/libffmpegkit.dll")
  if(NOT EXISTS "${FFMPEGKIT_ARCHIVE}")
    message(STATUS "FFmpegKit: скачиваю ${FFMPEGKIT_ARCHIVE_NAME}")
    file(DOWNLOAD
      "https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/${FFMPEGKIT_RELEASE}-${FFMPEGKIT_VARIANT}-windows/${FFMPEGKIT_ARCHIVE_NAME}"
      "${FFMPEGKIT_ARCHIVE}"
      TLS_VERIFY ON
      STATUS FFMPEGKIT_FETCH
    )
    list(GET FFMPEGKIT_FETCH 0 FFMPEGKIT_FETCH_CODE)
    if(NOT FFMPEGKIT_FETCH_CODE EQUAL 0)
      list(GET FFMPEGKIT_FETCH 1 FFMPEGKIT_FETCH_MSG)
      message(WARNING "FFmpegKit: скачать не вышло (${FFMPEGKIT_FETCH_MSG})")
      file(REMOVE "${FFMPEGKIT_ARCHIVE}")
    endif()
  endif()
  if(EXISTS "${FFMPEGKIT_ARCHIVE}")
    file(MAKE_DIRECTORY "${FFMPEGKIT_STAGE}")
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E tar xf "${FFMPEGKIT_ARCHIVE}"
      WORKING_DIRECTORY "${FFMPEGKIT_STAGE}"
      RESULT_VARIABLE FFMPEGKIT_UNTAR
    )
    if(NOT FFMPEGKIT_UNTAR EQUAL 0)
      message(WARNING "FFmpegKit: распаковать не вышло, оставляю плагину")
    endif()
  endif()
endif()
if(EXISTS "${FFMPEGKIT_STAGE}/bin/libffmpegkit.dll")
  set(ENV{FFMPEGKIT_LOCAL_DIR} "${FFMPEGKIT_STAGE}")
  message(STATUS "FFmpegKit: беру готовое из ${FFMPEGKIT_STAGE}")
endif()


# 🔴 СТАРЫЕ СОПРОГРАММЫ У ЧУЖИХ ПЛАГИНОВ.
#
# MSVC 14.51 (Visual Studio 18) превратил <experimental/coroutine> из
# предупреждения в ОШИБКУ (STL1011). На нём перестают собираться сразу три
# чужих плагина: just_audio_windows, local_auth_windows и
# permission_handler_windows — все они через C++/WinRT тянут старый заголовок.
# Их код не наш, и ждать, пока каждый переедет на <coroutine>, мы не можем.
# Microsoft для этого и оставил выключатель; он снимает именно эту проверку,
# ничего больше.
add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# 🔴 ОШИБКА УПАКОВКИ В ffmpeg_kit_flutter_new 4.2.1.
#
# Его собственный ffmpeg_kit_flutter_plugin_c_api.cpp подключает заголовок по
# пути include/ffmpeg_kit_flutter_new_full/…, а его же CMakeLists создаёт этот
# заголовок в include/ffmpeg_kit_flutter_new/… — без «_full». Пакет
# опубликован в таком виде и под Windows не собирается ни у кого. Поднять
# версию нельзя: тот же плагин стоит в ВЫПУЩЕННОЙ мобильной версии, а её мы не
# трогаем. Поэтому кладём рядом переходник по ожидаемому пути: он лишь
# отсылает к настоящему заголовку, ничего не объявляя сам.
if(TARGET ffmpeg_kit_flutter_new_plugin)
  set(FFMPEGKIT_SHIM_DIR
      "${CMAKE_BINARY_DIR}/ffmpeg-kit-shim/include/ffmpeg_kit_flutter_new_full")
  file(MAKE_DIRECTORY "${FFMPEGKIT_SHIM_DIR}")
  file(WRITE "${FFMPEGKIT_SHIM_DIR}/f_fmpeg_kit_flutter_plugin.h"
       "#include \"include/ffmpeg_kit_flutter_new/f_fmpeg_kit_flutter_plugin.h\"\n")
  target_include_directories(ffmpeg_kit_flutter_new_plugin PRIVATE
      "${CMAKE_BINARY_DIR}/ffmpeg-kit-shim")
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  OPTIONAL
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
