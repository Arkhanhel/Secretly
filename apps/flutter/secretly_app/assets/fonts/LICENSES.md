# Шрифты: авторы и лицензии

Приложение поставляется с 19 файлами шрифтов. Все они распространяются свободно,
но обе лицензии требуют, чтобы текст сопровождал распространение, — поэтому он
лежит здесь: [`OFL.txt`](OFL.txt) и
[`LICENSE-APACHE-2.0.txt`](LICENSE-APACHE-2.0.txt).

🔴 Данные ниже взяты **из самих файлов шрифтов** (таблица `name`, поля
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

🔴 **Экран лицензий сейчас есть только в настольной версии**
(`settings_workspace.dart`). На iOS и Android приложение везёт эти шрифты, но
показать их лицензии человеку негде. Для OFL и Apache 2.0 достаточно, что текст
приложен к дистрибутиву, — формального нарушения нет. Но пробел стоит закрыть до
подачи в аудит: аудитор посмотрит именно туда.
