// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// What a restore attempt actually found.
///
/// Lives apart from `billing_service.dart` so the paywall can tell the three
/// cases apart without importing the store SDK into the UI layer.
///
/// The distinction is the point: "you have nothing to restore" and "your
/// purchase did not apply" call for opposite next steps, and telling the second
/// group the first thing is how a paying customer concludes their money is gone.
enum RestoreOutcome {
  /// A paid tier is active now.
  restored,

  /// The store returned a purchase, but no paid entitlement followed within the
  /// wait. Support can fix this; the buyer cannot.
  purchaseNotApplied,

  /// The store has no purchase to restore for this account.
  nothingToRestore,
}
