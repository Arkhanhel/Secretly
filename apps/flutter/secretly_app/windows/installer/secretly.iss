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
; - Одна кнопка: ни выбора папки, ни выбора ярлыков, ни страницы «готово к
;   установке». Установщик сразу ставит программу, в конце — «Запустить».
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
VersionInfoVersion={#AppVersion}.{#AppBuild}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
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

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Secretly"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"

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
