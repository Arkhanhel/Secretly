#include "single_instance.h"

namespace {

// «Local\» — в пределах сеанса входа: у двух пользователей на одном
// компьютере свои Secretly.
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\Secretly.Desktop.SingleInstance";
constexpr wchar_t kShowWindowMessageName[] = L"Secretly.ShowMainWindow";
constexpr wchar_t kRunnerWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

struct FindState {
  DWORD self_pid;
  HWND found;
};

BOOL CALLBACK FindSecretlyWindow(HWND hwnd, LPARAM lparam) {
  auto* state = reinterpret_cast<FindState*>(lparam);
  wchar_t class_name[64] = {};
  if (::GetClassNameW(hwnd, class_name, 64) == 0) return TRUE;
  if (::lstrcmpW(class_name, kRunnerWindowClass) != 0) return TRUE;
  if (::GetPropW(hwnd, kSecretlyMainWindowProp) == nullptr) return TRUE;
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0 || pid == state->self_pid) return TRUE;
  state->found = hwnd;
  return FALSE;
}

}  // namespace

const wchar_t kSecretlyMainWindowProp[] = L"Secretly.MainWindow";

UINT SecretlyShowWindowMessage() {
  static const UINT message = ::RegisterWindowMessageW(kShowWindowMessageName);
  return message;
}

bool HandOffToRunningInstance() {
  // Дескриптор намеренно не закрываем: мьютекс должен жить, пока жив процесс,
  // и Windows освободит его сама при выходе.
  HANDLE mutex = ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (mutex == nullptr || ::GetLastError() != ERROR_ALREADY_EXISTS) {
    return false;
  }
  FindState state{::GetCurrentProcessId(), nullptr};
  ::EnumWindows(FindSecretlyWindow, reinterpret_cast<LPARAM>(&state));
  if (state.found == nullptr) {
    // Мьютекс занят, а окна нет: прежний процесс ещё поднимается или уже
    // уходит. Не мешаем запуску — дальше решит проверка на стороне Dart.
    ::CloseHandle(mutex);
    return false;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(state.found, &pid);
  ::AllowSetForegroundWindow(pid);
  ::PostMessageW(state.found, SecretlyShowWindowMessage(), 0, 0);
  ::CloseHandle(mutex);
  return true;
}
