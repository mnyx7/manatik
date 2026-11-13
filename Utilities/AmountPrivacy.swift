//
//  AmountPrivacy.swift
//  muna
//
//  Created by Minaya Yagubova on 11.11.26.
//

import Observation

/// Whether money is shown or masked, for glancing at the app in public.
///
/// `CurrencyFormatting` reads this, and every view formats money in its body,
/// so Observation redraws them all when it flips; no view has to opt in. The
/// saved value lives in `AppSettings.hidesAmounts`; RootView mirrors it here.
@MainActor
@Observable
final class AmountPrivacy {
    static let shared = AmountPrivacy()

    var isHidden = false

    /// What a masked amount reads as.
    static let mask = "••••"
}
