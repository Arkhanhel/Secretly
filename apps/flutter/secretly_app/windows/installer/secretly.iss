; SPDX-License-Identifier: AGPL-3.0-only
; SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
; Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
;
; Установщик Secretly для Windows (Inno Setup 6).
;
; Собирается в CI (.github/workflows/windows-release.yml) из готовой папки
; Release, куда уже положены библиотеки C++:
;
;   ISCC.exe /DAppVersion=1.8.62 /DAppBuild=633 /DBuildDir=<Release> ^
;            /DOutputDir=<куда> windows\installer\secretly.iss
;
; Решения (26.09.2026, указание владельца: «чтобы человек одной кнопкой
; установил грамотно и профессионально»):
;
; - Ставится на пользователя, в %LOCALAPPDATA%\Programs\Secretly, без окна
;   UAC — как Telegram, Signal, Slack. Администратор может поставить на всех
;   компьютер ключом /ALLUSERS в командной строке.
; - Одна кнопка: ни выбора папки, ни страницы «готово к установке». На первой
;   странице — одна галочка «ярлык на рабочем столе» (отмечена заранее) и
;   кнопка «Установить», в конце — «Запустить».
; - Удаление снимает и автозапуск, который программа пишет сама, — если он
;   ведёт на эту установку.
; - AppId НЕ МЕНЯЕТСЯ НИКОГДА: по нему новая версия встаёт поверх старой, а
;   не рядом, и Windows показывает одну строку в «Приложениях».
; - Данные человека (база, ключи, настройки) лежат в %APPDATA%, а не в папке
;   программы: ни обновление, ни удаление их не трогают.
; - Ярлык в «Пуске» несёт AppUserModelID "Secretly" — тот же, что ставит
;   local_notifier для уведомлений Windows. Иначе уведомления искали бы свой
;   ярлык и переписывали наш.
; - Крестик окна у нас прячет в трей, поэтому мягко закрыть программу извне
;   нельзя: CloseApplications=force. Обновление из приложения закрывает его
;   само перед установкой.
; - Тихое обновление из приложения: /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
;   /CLOSEAPPLICATIONS /LAUNCH=1 — поставить и снова открыть.
; - Подпись кода (Authenticode) — отдельный шаг, когда будет сертификат:
;   ISCC /DSignTool=signtool /Ssigntool="signtool.exe sign ... $f" — установщик
;   и деинсталлятор подпишутся.

#ifndef AppVersion
  #error Нужен номер версии: /DAppVersion=1.8.62
#endif
#ifndef AppBuild
  #error Нужен номер сборки: /DAppBuild=633
#endif
#ifndef BuildDir
  #error Нужна папка сборки: /DBuildDir=...\build\windows\x64\runner\Release
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define AppName "Secretly"
#define AppExe "Secretly.exe"
#define AppPublisher "SIA Secretly"
#define AppUrl "https://www.secretlyapp.com"

[Setup]
AppId={{A475E0B8-A2A2-4298-B913-DDE939EEF2D5}
AppName={#AppName}
AppVersion={#AppVersion} ({#AppBuild})
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/support
AppUpdatesURL={#AppUrl}/download
AppCopyright=(C) 2025-2026 Yurii Arkhanhelskyi, AGPL-3.0
; Номер сборки — четвёртой частью обеих версий файла: по нему видно, какая
; сборка внутри, и его прочтёт проверка обновления (30.09.2026).
VersionInfoVersion={#AppVersion}.{#AppBuild}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}.{#AppBuild}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
DefaultDirName={autopf}\{#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
WizardStyle=modern
ShowLanguageDialog=auto
LanguageDetectionMethod=uilanguage
SetupIconFile=..\runner\resources\app_icon.ico
; Картинка в шапке мастера — тот же знак, что у программы, вместо встроенной
; картинки Inno Setup (делает tools/make_windows_icons.py). PNG с прозрачностью
; Inno Setup читает с 6.5.2, в CI стоит 6.7.1. Площадь картинки квадратная и
; растёт с масштабом экрана (58…159 px на 100…250 %) — Setup сам берёт файл
; нужного размера. В публичной выкладке оформления нет: тогда остаётся
; встроенная картинка, а сборка установщика не падает.
#if FileExists(AddBackslash(SourcePath) + "wizard_small_58.png")
WizardSmallImageFile=wizard_small_58.png,wizard_small_77.png,wizard_small_97.png,wizard_small_116.png,wizard_small_124.png,wizard_small_143.png,wizard_small_159.png
#endif
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
CloseApplications=force
RestartApplications=no
Compression=lzma2/max
SolidCompression=yes
SetupLogging=yes
OutputDir={#OutputDir}
OutputBaseFilename=Secretly-Setup-{#AppVersion}-{#AppBuild}-x64
#ifdef SignTool
SignTool={#SignTool}
SignedUninstaller=yes
#endif

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "uk"; MessagesFile: "compiler:Languages\Ukrainian.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "pt"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[InstallDelete]
; Ресурсы Flutter прошлой версии: файлы, которых в новой нет, не должны
; остаться рядом с новыми. Данных человека здесь нет — они в %APPDATA%.
Type: filesandordirs; Name: "{app}\data"
; Имя до 1.8.62: в «Диспетчере задач» процесс назывался secretly_app.exe.
; Если кто-то поставил ту сборку, старый файл рядом с новым не нужен.
Type: files; Name: "{app}\secretly_app.exe"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Tasks]
; Ярлык на рабочем столе — по выбору, отмечен заранее (30.09.2026). Тихое
; обновление повторяет прежний выбор человека (UsePreviousTasks).
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Secretly"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Обычная установка: галочка «Запустить Secretly» на последней странице.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent runasoriginaluser
; Тихое обновление из приложения: /LAUNCH=1 — снова открыть после установки.
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: LaunchAfterSilentUpdate

[Code]
function LaunchAfterSilentUpdate: Boolean;
begin
  Result := WizardSilent and (ExpandConstant('{param:LAUNCH|0}') = '1');
end;

// Автозапуск программа пишет сама (desktop_login_item_windows.dart): значение
// Secretly в HKCU\...\Run. Без этого шага оно переживало удаление и при входе
// в Windows звало несуществующий файл. Снимаем его, только если оно ведёт на
// ЭТУ установку: переносная копия из архива пишет то же имя со своим путём.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Entry: String;
begin
  if CurUninstallStep <> usUninstall then
    Exit;
  if RegQueryStringValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Secretly', Entry) and
     (Pos(Lowercase(ExpandConstant('{app}\{#AppExe}')), Lowercase(Entry)) > 0) then
  begin
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Secretly');
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', 'Secretly');
  end;
end;
