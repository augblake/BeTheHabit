import HabitShared
import Foundation
import SwiftUI

struct HabitIconCategory: Identifiable {
    let name: String
    let symbols: [String]

    var id: String { name }
}

enum HabitIconCatalog {
    static let categories: [HabitIconCategory] = [
        HabitIconCategory(name: "Popular", symbols: [
            "star.fill", "sparkles", "target", "flag.fill", "bolt.fill", "trophy.fill",
            "checkmark.seal.fill", "heart.fill", "flame.fill", "leaf.fill", "sun.max.fill", "moon.stars.fill"
        ]),
        HabitIconCategory(name: "Mind & Spirit", symbols: [
            "hands.sparkles.fill", "brain.head.profile", "eye.fill", "moon.stars.fill", "sunrise.fill", "sunset.fill",
            "sparkle", "hands.clap.fill", "heart.text.square.fill", "figure.mind.and.body", "leaf.fill", "candle.flame.fill",
            "book.closed.fill", "cross.fill", "water.waves", "hands.sparkles.fill"
        ]),
        HabitIconCategory(name: "Health", symbols: [
            "heart.fill", "heart.text.square.fill", "waveform.path.ecg", "cross.case.fill", "pills.fill", "bandage.fill",
            "lungs.fill", "figure.run", "figure.walk", "figure.cooldown", "figure.strengthtraining.traditional", "figure.pool.swim",
            "dumbbell.fill", "bicycle", "bed.double.fill", "cross.vial.fill", "figure.hiking", "figure.boxing"
        ]),
        HabitIconCategory(name: "Food & Drink", symbols: [
            "fork.knife", "carrot.fill", "takeoutbag.and.cup.and.straw.fill", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
            "fish.fill", "birthday.cake.fill", "leaf.fill", "carrot.fill", "waterbottle.fill", "basket.fill",
            "takeoutbag.and.cup.and.straw.fill", "frying.pan.fill", "refrigerator.fill", "popcorn.fill"
        ]),
        HabitIconCategory(name: "Work & Study", symbols: [
            "book.fill", "book.closed.fill", "books.vertical.fill", "pencil", "pencil.and.outline", "graduationcap.fill",
            "laptopcomputer", "desktopcomputer", "keyboard", "briefcase.fill", "lightbulb.fill", "brain.head.profile",
            "calendar", "clock.fill", "chart.line.uptrend.xyaxis", "doc.text.fill", "folder.fill", "globe"
        ]),
        HabitIconCategory(name: "Home & Life", symbols: [
            "house.fill", "bed.double.fill", "sofa.fill", "washer.fill", "basket.fill", "lightbulb.fill",
            "cup.and.saucer.fill", "paintbrush.pointed.fill", "hammer.fill", "wrench.fill", "sparkles", "key.fill",
            "car.fill", "pawprint.fill", "lock.fill", "shippingbox.fill", "tent.fill", "tree.fill"
        ]),
        HabitIconCategory(name: "Creative", symbols: [
            "paintpalette.fill", "music.note", "music.mic", "guitars.fill", "pianokeys", "camera.fill",
            "photo.fill", "scissors", "theatermasks.fill", "gamecontroller.fill", "film.fill", "headphones",
            "scribble.variable", "theatermasks", "speaker.wave.2.fill", "wand.and.stars"
        ]),
        HabitIconCategory(name: "Digital Balance", symbols: [
            "bell.slash.fill", "wifi.slash",
            "airplane", "moon.zzz.fill", "eye.slash.fill", "speaker.slash.fill", "app.badge", "timer",
            "hourglass", "stopwatch.fill", "hand.raised.fill", "checkmark.circle.fill"
        ]),
        HabitIconCategory(name: "Money & Goals", symbols: [
            "dollarsign.circle.fill", "creditcard.fill", "banknote.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis", "giftcard.fill",
            "building.columns.fill", "wallet.pass.fill", "percent", "arrow.up.right.circle.fill", "medal.fill", "rosette"
        ]),
        HabitIconCategory(name: "People & Community", symbols: [
            "person.fill", "person.2.fill", "person.3.fill", "figure.2", "figure.2.and.child.holdinghands", "person.crop.circle.fill",
            "bubble.left.and.bubble.right.fill", "phone.fill", "hands.clap.fill", "hand.wave.fill", "gift.fill", "heart.fill"
        ]),
        HabitIconCategory(name: "Nature & Outdoors", symbols: [
            "leaf.fill", "tree.fill", "sun.max.fill", "moon.fill", "cloud.sun.fill", "cloud.rain.fill",
            "wind", "drop.fill", "flame.fill", "snowflake", "mountain.2.fill", "water.waves",
            "pawprint.fill", "bird.fill", "fish.fill", "flower.fill", "globe.americas.fill", "sun.horizon.fill"
        ])
    ]

    static let allSymbols = Array(Set(categories.flatMap(\.symbols) + HabitPresetCatalog.all.map(\.symbol))).sorted()

    static func defaultSymbol(for habit: Habit) -> String {
        let name = habit.name.lowercased()
        let matches: [(words: [String], symbol: String)] = [
            (["water", "drink", "hydrate"], "drop.fill"),
            (["run", "walk", "cardio"], "figure.run"),
            (["meditat", "mindful", "yoga"], "figure.mind.and.body"),
            (["read", "book"], "book.fill"),
            (["push", "workout", "exercise", "gym", "strength"], "dumbbell.fill"),
            (["sleep", "bed", "rest"], "moon.fill"),
            (["heart", "love"], "heart.fill"),
            (["food", "eat", "diet", "healthy", "plant"], "leaf.fill")
        ]

        return matches.first(where: { group in
            group.words.contains(where: { name.contains($0) })
        })?.symbol ?? habit.trackingMode.icon
    }
}

enum HabitIconPalette {
    static let defaultHex = "40D1D1"

    static let colors: [(name: String, hex: String)] = [
        ("Teal", "40D1D1"), ("Blue", "4F91FF"), ("Sky", "39BCE5"),
        ("Green", "4EC77A"), ("Lime", "91C83E"), ("Yellow", "F0BB3E"),
        ("Orange", "F28A3D"), ("Red", "F05B62"), ("Pink", "EA70A4"),
        ("Purple", "9A70E8"), ("Indigo", "6C76D9"), ("Gray", "9AA4B2")
    ]
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0x40D1D1
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
