cmake_minimum_required(VERSION 3.22)
project(whisper_flutter LANGUAGES C CXX)
# Secretly vendoring patch (26.09.2026): Google Play отклоняет бандл, если
# LOAD-сегменты .so выровнены меньше чем на 16 КБ (устройства со страницами
# памяти 16 КБ, Android 15+). Плагин собирается NDK по умолчанию для AGP
# (r27, 4 КБ), а не NDK приложения (r28), — все его библиотеки (ggml*, whisper,
# parakeet, whisper_flutter) выходили с 4 КБ с 06.09. Флаг задан ДО
# add_subdirectory, чтобы дошёл до всех общих библиотек дерева.
if(ANDROID)
  string(APPEND CMAKE_SHARED_LINKER_FLAGS " -Wl,-z,max-page-size=16384")
endif()
set(CMAKE_CXX_STANDARD 17)
set(BUILD_SHARED_LIBS OFF)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(WHISPER_NATIVE_ROOT ios/whisper_cpp_flutter_plus/Sources)
add_subdirectory(${WHISPER_NATIVE_ROOT}/WhisperCppCore whisper-build)
add_library(whisper_flutter SHARED
  ${WHISPER_NATIVE_ROOT}/WhisperCppFlutterBridge/whisper_flutter.cpp)
target_include_directories(whisper_flutter PRIVATE
  ${WHISPER_NATIVE_ROOT}/WhisperCppFlutterBridge
  ${WHISPER_NATIVE_ROOT}/WhisperCppCore/include)
target_link_libraries(whisper_flutter PRIVATE whisper)
if(ANDROID)
  target_link_libraries(whisper_flutter PRIVATE log android)
endif()
