# Шрифты: авторы и лицензии

Приложение поставляется с 19 файлами шрифтов; сборка Windows — ещё с одним,
шрифтом эмодзи (см. раздел «Только сборка Windows»). Все они распространяются
свободно, но обе лицензии требуют, чтобы текст сопровождал распространение, —
поэтому он лежит здесь: [`OFL.txt`](OFL.txt) и
[`LICENSE-APACHE-2.0.txt`](LICENSE-APACHE-2.0.txt).

Данные ниже взяты **из самих файлов шрифтов** (таблица `name`, поля
«копирайт», «дизайнер», «ссылка на лицензию»), а не из памяти и не с сайта.
Проверить можно, прочитав метаданные любого `.ttf` — так исключена ошибка
«приложили не ту лицензию».

## SIL Open Font License 1.1

| Семейство | Автор | Копирайт |
|---|---|---|
| Anton | Vernon Adams | Vernon Adams |
| Bangers | Vernon Adams | Vernon Adams |
| Bebas Neue | Ryoichi Tsunekawa (Dharma Type) | Ryoichi Tsunekawa |
| Creepster | Font Diner, Inc. | Font Diner |
| Inter | Rasmus Andersson | Rasmus Andersson |
| Kalam | Lipi Raval, Indian Type Foundry | © 2014 Indian Type Foundry |
| Lobster | Impallari Type | Impallari Type |
| Manrope | Mikhail Sharanda | © 2018 Mikhail Sharanda |
| Monoton | Vernon Adams | © 2011 Vernon Adams |
| Pacifico | Vernon Adams | Vernon Adams |
| Press Start 2P | CodeMan38 | CodeMan38 |
| Righteous | Astigmatic (AOETI) | Astigmatic |

Файлы: `Anton-Regular`, `Bangers-Regular`, `BebasNeue-Regular`,
`Creepster-Regular`, `Inter-Regular/Medium/SemiBold/Bold/ExtraBold`,
`InterVariable`, `Kalam-Regular`, `Lobster-Regular`,
`Manrope-Regular/Medium/SemiBold/Bold/ExtraBold`, `Monoton-Regular`,
`Pacifico-Regular`, `PressStart2P-Regular`, `Righteous-Regular`.

**Оговорка по Monoton.** В отличие от остальных, этот файл **не несёт ссылки на
лицензию** в метаданных — только копирайт Vernon Adams, 2011. На Google Fonts
семейство опубликовано под OFL 1.1, и здесь оно отнесено туда же. Это
единственная строка таблицы, опирающаяся не на сам файл; при подготовке к
внешнему аудиту стоит перекачать файл из официального репозитория Google Fonts,
где `OFL.txt` лежит рядом.

## Apache License 2.0

| Семейство | Автор | Копирайт |
|---|---|---|
| Roboto | Christian Robertson, Google | © 2011 Google Inc. |

Файлы: `Roboto-Regular`, `Roboto-Medium`, `Roboto-Bold`.

Именно эта версия Roboto распространяется под Apache 2.0 — так записано в самих
файлах. Более поздние выпуски Google Fonts переведены на OFL; если шрифт будут
обновлять, лицензию надо перечитать из нового файла, а не переносить отсюда.

## Только сборка Windows: шрифт эмодзи (30.09.2026, Э1)

| Семейство | Автор | Копирайт | Лицензия |
|---|---|---|---|
| Noto Color Emoji 2.057 | Google | Copyright 2022 Google Inc. | SIL OFL 1.1 |

Файл: `windows/fonts/NotoColorEmoji_WindowsCompatible.ttf`. В сборке Windows он
лежит в `data\` рядом с `Secretly.exe` (правило `install(FILES …)` в
`windows/CMakeLists.txt`). Ассетом `pubspec.yaml` он **не** заявлен: телефон и
macOS его не везут — эмодзи там рисует система (Noto на Android, Apple на iOS и
macOS). Зачем он нужен: без него Windows рисует эмодзи шрифтом Segoe UI Emoji,
не как на телефоне.

Откуда взят — только из официального репозитория Google, без правок, байт в
байт:

- репозиторий: <https://github.com/googlefonts/noto-emoji>, выпуск
  `v2026-09-24-unicode18_0` («Unicode 18.0», 24.09.2026), коммит
  `e20cbc2bbec1926686be9f9bee7d1d2cfa1fea0e`;
- путь в репозитории: `2D/fonts/NotoColorEmoji_WindowsCompatible.ttf` (до
  17.09.2026 — `fonts/…`, перенесён коммитом `1ffdd213` «Add Emoji 18 fonts»);
- скачан 30.09.2026 по адресу
  `https://raw.githubusercontent.com/googlefonts/noto-emoji/e20cbc2bbec1926686be9f9bee7d1d2cfa1fea0e/2D/fonts/NotoColorEmoji_WindowsCompatible.ttf`;
- размер 10 739 048 байт, SHA-256
  `2c7ede2f5438f9c1da098778bd681535933a345334008bb03fc51119f6b1cd72`;
- git-объект `a8a20c176af79a98e73a9c7b62aaa71eb88a5b14` — совпадает с объектом
  этого пути в репозитории Google на указанном коммите.

Метаданные из таблицы `name` самого файла: копирайт «Copyright 2022 Google
Inc.», лицензия «This Font Software is licensed under the SIL Open Font License,
Version 1.1» со ссылкой `http://scripts.sil.org/OFL`, версия
`Version 2.057;GOOG;noto-emoji:20260911:fc4ca365e7c20e78278ae702aa20434bfe704c8f`.
Зарезервированных имён (Reserved Font Name) в копирайте не указано; файл и не
изменён. Текст лицензии — [`OFL.txt`](OFL.txt).

В программе шрифт регистрируется под своим именем `SecretlyEmoji`, а не
«Noto Color Emoji»: это имя стоит в телефонных списках запасных шрифтов, и
вшитый файл перехватил бы эмодзи там, где его формат не рисуется (iPhone).
Лицензия видна на экране лицензий только в программе для Windows
(`registerWindowsEmojiFontLicense` в `lib/legal/third_party_licenses.dart`).
Сумму и путь сторожит `test/desktop_emoji_font_windows_test.dart`; если файл
будут обновлять — скачать заново оттуда же и поправить сумму, коммит и версию
здесь и в тесте.

## Сторонний код в дереве

| Каталог | Автор | Лицензия |
|---|---|---|
| `third_party/audiotags` | Erikas Taroza, 2023 | MIT |
| `third_party/liquid_glass_widgets` | Sebastian Degenaar, 2024 | MIT |

Тексты — в `LICENSE` внутри каждого каталога.

## Где это видно человеку

Лицензии регистрируются в `LicenseRegistry` (см.
`lib/legal/third_party_licenses.dart`) и потому попадают в системный экран
лицензий Flutter.

**Экран лицензий сейчас есть только в настольной версии**
(`settings_workspace.dart`). На iOS и Android приложение везёт эти шрифты, но
показать их лицензии человеку негде. Для OFL и Apache 2.0 достаточно, что текст
приложен к дистрибутиву, — формального нарушения нет. Но пробел стоит закрыть до
подачи в аудит: аудитор посмотрит именно туда.
