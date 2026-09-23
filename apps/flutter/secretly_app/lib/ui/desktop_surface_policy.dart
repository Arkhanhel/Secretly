// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Single source of truth for **when the mobile entrypoint is allowed to
/// render the legacy wide layout** ("Surface B").
///
/// Background. The project ships two desktop surfaces:
///
/// * **Surface A (the product)** — `lib/main_desktop.dart` →
///   `lib/ui/desktop/**`. Native chrome, tray, single-instance, mouse-first.
/// * **Surface B (legacy)** — `lib/main.dart` → [AppShell] /
///   [ChatsScreen] → `lib/ui/desktop_chats_workspace.dart`, which embeds the
///   *mobile* `ChatScreen` in a NavigationRail frame.
///
/// Until now both sites hand-rolled the same predicate
/// (`Platform.isWindows || Platform.isLinux || Platform.isMacOS || width >= 1180`),
/// so building the mobile target on a desktop OS produced a second, divergent
/// desktop app — the "double buttons" failure mode.
///
/// Policy now:
///
/// * **Desktop OS** — Surface B is off. The mobile entrypoint renders the
///   mobile layout, and the only desktop product is Surface A. Roll back with
///   `--dart-define=SECRETLY_LEGACY_DESKTOP_ON_DESKTOP_OS=true`.
/// * **Wide tablets** (iPad, large Android) — unchanged. iPad is a shipped
///   device family and 11"/12.9" landscape exceeds the breakpoint, so real
///   users are on Surface B today. They move
///   to Surface A only after it is split into platform-neutral widgets with
///   touch ergonomics (epic T-01…T-06) — not before.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Width at or above which a *touch* device gets the legacy wide layout.
///
/// 1180 logical pixels: below an 11" iPad in landscape (1194), above every
/// phone and every iPad in portrait.
const double kWideLayoutBreakpoint = 1180;

/// Escape hatch: re-enable Surface B on macOS/Windows/Linux.
///
/// Only for bisecting a regression against the pre-2026-09-08 behaviour.
/// Never set this in a release build — the desktop product is Surface A,
/// built with `--target=lib/main_desktop.dart`.
const bool kLegacyDesktopSurfaceOnDesktopOs =
    bool.fromEnvironment('SECRETLY_LEGACY_DESKTOP_ON_DESKTOP_OS');

/// True on macOS, Windows or Linux (never on web).
bool get isDesktopOs =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Whether the mobile entrypoint should render the legacy wide layout
/// (`DesktopChatsWorkspace` / the NavigationRail shell) at [width].
///
/// [width] is the logical width of the window — `MediaQuery.sizeOf(context).width`.
bool useLegacyWideLayout(double width) =>
    legacyWideLayoutFor(isDesktop: isDesktopOs, width: width);

/// The decision itself, with the platform passed in.
///
/// Split out so BOTH branches can be tested. Unit tests run on the VM, where
/// [isDesktopOs] is always true, so a test of [useLegacyWideLayout] alone can
/// never exercise the phone/tablet path — and that path is the shipped mobile
/// behaviour, which must stay bit-identical to what it was before the
/// desktop-OS opt-out was introduced.
bool legacyWideLayoutFor({required bool isDesktop, required double width}) {
  if (isDesktop) return kLegacyDesktopSurfaceOnDesktopOs;
  return width >= kWideLayoutBreakpoint;
}
