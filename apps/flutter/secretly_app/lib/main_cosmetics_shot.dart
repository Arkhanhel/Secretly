// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// DEV-ONLY preview harness for premium cosmetics (frames + covers).
// Renders every animated frame on a sample avatar + every cover banner so we
// can screenshot and review the look. Not referenced by any release entrypoint.
//
// Run: flutter build apk --debug -t lib/main_cosmetics_shot.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/premium/cosmetics_catalog.dart';
import 'ui/widgets/framed_avatar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CosmeticsShotApp());
}

class CosmeticsShotApp extends StatelessWidget {
  const CosmeticsShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4A6BFF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const _CosmeticsPreview(),
    );
  }
}

class _CosmeticsPreview extends StatelessWidget {
  const _CosmeticsPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D11),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          _section('Рамки (10)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final f in kAvatarFrames)
                SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      FramedAvatar(
                        size: 88,
                        fallbackSeed: f.id,
                        fallbackName: 'Secretly',
                        frameId: f.id,
                      ),
                      const SizedBox(height: 6),
                      Text(f.nameRu,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _section('Обложки (6)'),
          const SizedBox(height: 8),
          for (final c in kProfileCovers) ...[
            Text(c.nameRu,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(height: 110, width: double.infinity, child: c.builder()),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _section(String t) => Text(
        t,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
      );
}
