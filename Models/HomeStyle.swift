//
//  HomeStyle.swift
//  muna
//
//  Created by Minaya Yagubova on 11.11.26.
//

import Foundation

/// The home page the user picked in Settings.
///
/// Classic is the original card layout. The others are illustrated rooms: the
/// scenery is a picture, and every object on the shelves is a live, tappable
/// control drawn on top of it.
enum HomeStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case classic
    case cozyGirl
    case cozyBoy
    case cozyChristmas
    case posterGirl
    case posterBoy
    case posterChristmas

    var id: String { rawValue }

    enum Family {
        case cozy
        case poster
    }

    /// Nil for Classic, which has no illustration.
    var family: Family? {
        switch self {
        case .classic: return nil
        case .cozyGirl, .cozyBoy, .cozyChristmas: return .cozy
        case .posterGirl, .posterBoy, .posterChristmas: return .poster
        }
    }

    var isChristmas: Bool { self == .cozyChristmas || self == .posterChristmas }

    /// Asset catalog name of the scenery behind the live objects.
    var backgroundImageName: String? {
        switch self {
        case .classic: return nil
        case .cozyGirl: return "home-cozy-shelf-bg"
        case .cozyBoy: return "home-cozy-shelf-boy-bg"
        case .cozyChristmas: return "home-cozy-shelf-xmas-bg"
        case .posterGirl: return "home-poster-bg"
        case .posterBoy: return "home-poster-boy-bg"
        case .posterChristmas: return "home-poster-xmas-bg"
        }
    }

    var localizedTitle: String {
        switch self {
        case .classic: return AppLocalization.string("Classic", comment: "Home style")
        case .cozyGirl: return AppLocalization.string("Cozy", comment: "Home style")
        case .cozyBoy: return AppLocalization.string("Cozy, him", comment: "Home style")
        case .cozyChristmas: return AppLocalization.string("Cozy Christmas", comment: "Home style")
        case .posterGirl: return AppLocalization.string("Poster", comment: "Home style")
        case .posterBoy: return AppLocalization.string("Poster, him", comment: "Home style")
        case .posterChristmas: return AppLocalization.string("Poster Christmas", comment: "Home style")
        }
    }
}
