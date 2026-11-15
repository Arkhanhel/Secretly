#!/usr/bin/env python3
"""Перечень зависимостей (SBOM) в формате CycloneDX 1.5.

Зачем. Фонды и проверяющие спрашивают не «какие библиотеки вы любите», а
«покажите список с версиями». Без него ответ на «а нет ли у вас уязвимой
версии X» — чтение `pubspec.lock` глазами. Европейский регламент о
киберустойчивости (CRA) делает такой перечень обязательным для продуктов с
цифровыми элементами, и проще иметь его заранее.

🔴 СОБИРАЕТСЯ ИЗ ФАЙЛОВ БЛОКИРОВКИ, А НЕ ИЗ МАНИФЕСТОВ. `pubspec.yaml` и
`Cargo.toml` говорят «что просили» («^2.0.0»), а поставлено то, что записано в
`pubspec.lock` и `Cargo.lock`. Для перечня уязвимостей нужна именно
поставленная версия, иначе он описывает не то, что ушло людям.

Зависимостей не добавляет: читает только текстовые файлы.

Запуск из корня репозитория:

    python3 tools/build_sbom.py                 # → artifacts/sbom/
    python3 tools/build_sbom.py --check         # сверить с записанным
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import sys

APP = 'apps/flutter/secretly_app'
OUT_DIR = 'artifacts/sbom'
SPEC = '1.5'

# Лицензия приложения; у отдельных частей свои (см. поле `licenses` ниже).
APP_LICENSE = 'AGPL-3.0-only'


def read(path):
    try:
        return open(path, encoding='utf-8').read()
    except OSError:
        return ''


def pub_packages(lock_text):
    """Пакеты из pubspec.lock. Формат — YAML, но нам нужны три поля.

    Разбираем построчно, без зависимости от библиотеки YAML: в перечне не
    должно быть ничего, чего нет в репозитории.
    """
    out = []
    name = None
    version = None
    source = None
    dependency = None
    for raw in lock_text.split('\n'):
        if re.match(r'^  [a-zA-Z0-9_]+:$', raw):
            if name and version:
                out.append((name, version, source or 'hosted', dependency or ''))
            name = raw.strip().rstrip(':')
            version = source = dependency = None
            continue
        m = re.match(r'^    version: "?([^"]+)"?$', raw)
        if m:
            version = m.group(1)
        m = re.match(r'^    source: (.+)$', raw)
        if m:
            source = m.group(1).strip().strip('"')
        m = re.match(r'^    dependency: "?([^"]+)"?$', raw)
        if m:
            dependency = m.group(1)
    if name and version:
        out.append((name, version, source or 'hosted', dependency or ''))
    # Служебные разделы файла блокировки пакетами не являются.
    return [p for p in out if p[0] not in ('sdks', 'packages')]


def cargo_packages(lock_text):
    """Пакеты из Cargo.lock (формат TOML, блоки [[package]])."""
    out = []
    name = version = None
    for raw in lock_text.split('\n'):
        if raw.strip() == '[[package]]':
            if name and version:
                out.append((name, version))
            name = version = None
            continue
        m = re.match(r'^name = "([^"]+)"$', raw.strip())
        if m:
            name = m.group(1)
        m = re.match(r'^version = "([^"]+)"$', raw.strip())
        if m:
            version = m.group(1)
    if name and version:
        out.append((name, version))
    return out


def component(name, version, purl_type, scope, extra=None):
    c = {
        'type': 'library',
        'name': name,
        'version': version,
        'purl': f'pkg:{purl_type}/{name}@{version}',
        'scope': scope,
    }
    if extra:
        c.update(extra)
    return c


def build(repo):
    pub = pub_packages(read(os.path.join(repo, APP, 'pubspec.lock')))
    cargo_roots = [
        ('Cargo.lock', 'серверы и общий код'),
        (os.path.join(APP, 'third_party/secretly_transport_ffi/rust/Cargo.lock'),
         'библиотека транспорта'),
    ]
    components = []
    seen = set()

    for name, version, source, dependency in pub:
        # `direct main` едет людям; `direct dev` и `transitive` помечаем иначе.
        scope = 'required' if dependency.startswith('direct main') else 'optional'
        if dependency == 'transitive':
            scope = 'required'
        key = ('pub', name, version)
        if key in seen:
            continue
        seen.add(key)
        extra = {}
        if source == 'path':
            extra['description'] = 'своя копия в third_party (см. MODIFICATIONS.md)'
        components.append(component(name, version, 'pub', scope, extra))

    for rel, note in cargo_roots:
        for name, version in cargo_packages(read(os.path.join(repo, rel))):
            key = ('cargo', name, version)
            if key in seen:
                continue
            seen.add(key)
            components.append(
                component(name, version, 'cargo', 'required',
                          {'description': note})
            )

    components.sort(key=lambda c: (c['purl'],))
    return components


def document(components, serial_seed):
    # 🔴 БЕЗ МЕТКИ ВРЕМЕНИ В САМОМ ДОКУМЕНТЕ. Иначе каждый прогон даёт новый
    # файл, `--check` всегда ругается, а в истории — шум вместо изменений
    # состава. Дата сборки перечня остаётся в отчёте рядом.
    digest = hashlib.sha256(serial_seed.encode()).hexdigest()
    return {
        'bomFormat': 'CycloneDX',
        'specVersion': SPEC,
        'serialNumber': f'urn:uuid:{digest[:8]}-{digest[8:12]}-{digest[12:16]}'
                        f'-{digest[16:20]}-{digest[20:32]}',
        'version': 1,
        'metadata': {
            'component': {
                'type': 'application',
                'name': 'secretly',
                'description': 'End-to-end encrypted messenger',
                'licenses': [{'license': {'id': APP_LICENSE}}],
            },
            'properties': [
                {'name': 'secretly:source',
                 'value': 'pubspec.lock + Cargo.lock (установленные версии)'},
            ],
        },
        'components': components,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out-dir', default=OUT_DIR)
    ap.add_argument('--check', action='store_true',
                    help='сверить записанный перечень с файлами блокировки')
    args = ap.parse_args()

    repo = os.getcwd()
    if not os.path.isdir(os.path.join(repo, APP)):
        print('error: запускать из корня репозитория', file=sys.stderr)
        return 1

    components = build(repo)
    if not components:
        print('error: ни одной зависимости не найдено — проверьте файлы '
              'блокировки', file=sys.stderr)
        return 1

    seed = '\n'.join(c['purl'] for c in components)
    doc = document(components, seed)
    rendered = json.dumps(doc, ensure_ascii=False, indent=2) + '\n'
    path = os.path.join(repo, args.out_dir, 'secretly.cdx.json')

    pub_n = sum(1 for c in components if c['purl'].startswith('pkg:pub/'))
    cargo_n = len(components) - pub_n

    if args.check:
        current = read(path)
        if not current:
            print(f'error: нет {args.out_dir}/secretly.cdx.json — '
                  'запустите скрипт без --check', file=sys.stderr)
            return 1
        if current != rendered:
            print('error: перечень зависимостей разошёлся с файлами '
                  'блокировки — запустите скрипт без --check', file=sys.stderr)
            return 1
        print(f'перечень сходится: Dart {pub_n}, Rust {cargo_n}')
        return 0

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(rendered)
    today = datetime.date.today().isoformat()
    print(f'{args.out_dir}/secretly.cdx.json: Dart {pub_n}, Rust {cargo_n}, '
          f'всего {len(components)} (собран {today})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
