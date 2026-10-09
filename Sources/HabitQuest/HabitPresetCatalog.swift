import HabitShared
import Foundation
import UIKit

struct HabitPreset: Identifiable {
    let name: String
    let category: String
    let symbol: String
    let colorHex: String

    var id: String { name }

    var suggestedType: HabitType {
        name.hasPrefix("No ") || name.hasPrefix("Limit ") || name == "Drink less alcohol"
            ? .remove
            : .build
    }

    var suggestedTrackingMode: TrackingMode {
        let timerHabits: Set<String> = [
            "Deep work", "Pomodoro sessions", "Track work hours", "Relax without screens",
            "Spend time outside", "Unplug for an hour", "Intermittent fasting"
        ]
        if timerHabits.contains(name) { return .timer }

        let measurableHabits: Set<String> = [
            "Hit step goal", "Track calories", "Hit protein goal", "Sleep 8 hours",
            "Limit screen time", "Limit social media", "Limit gaming", "Limit caffeine"
        ]
        return measurableHabits.contains(name) ? .number : .yesNo
    }
}

enum HabitPresetCatalog {
    static let all: [HabitPreset] = [
        HabitPreset(name: "Exercise", category: "Health & Fitness", symbol: "figure.run", colorHex: "FF6B6B"),
        HabitPreset(name: "Walk", category: "Health & Fitness", symbol: "figure.walk", colorHex: "45C486"),
        HabitPreset(name: "Run", category: "Health & Fitness", symbol: "figure.run", colorHex: "FF5B63"),
        HabitPreset(name: "Go to the gym", category: "Health & Fitness", symbol: "dumbbell.fill", colorHex: "A276FF"),
        HabitPreset(name: "Stretch", category: "Health & Fitness", symbol: "figure.cooldown", colorHex: "42C8C5"),
        HabitPreset(name: "Yoga", category: "Health & Fitness", symbol: "figure.mind.and.body", colorHex: "B16CFF"),
        HabitPreset(name: "Strength training", category: "Health & Fitness", symbol: "figure.strengthtraining.traditional", colorHex: "638BFF"),
        HabitPreset(name: "Push-ups", category: "Health & Fitness", symbol: "figure.strengthtraining.traditional", colorHex: "FF8A50"),
        HabitPreset(name: "Squats", category: "Health & Fitness", symbol: "figure.strengthtraining.traditional", colorHex: "E46DAB"),
        HabitPreset(name: "Pull-ups", category: "Health & Fitness", symbol: "figure.strengthtraining.traditional", colorHex: "4F9DFF"),
        HabitPreset(name: "Cardio", category: "Health & Fitness", symbol: "heart.fill", colorHex: "FF4F72"),
        HabitPreset(name: "Cycle", category: "Health & Fitness", symbol: "bicycle", colorHex: "49B8D8"),
        HabitPreset(name: "Swim", category: "Health & Fitness", symbol: "figure.pool.swim", colorHex: "35A9F2"),
        HabitPreset(name: "Hit step goal", category: "Health & Fitness", symbol: "shoe.fill", colorHex: "53C993"),
        HabitPreset(name: "Drink water", category: "Health & Fitness", symbol: "drop.fill", colorHex: "26A8FF"),
        HabitPreset(name: "Eat healthy", category: "Health & Fitness", symbol: "leaf.fill", colorHex: "54C878"),
        HabitPreset(name: "Eat vegetables", category: "Health & Fitness", symbol: "carrot.fill", colorHex: "F28B35"),
        HabitPreset(name: "Eat fruit", category: "Health & Fitness", symbol: "carrot.fill", colorHex: "F45E87"),
        HabitPreset(name: "Track calories", category: "Health & Fitness", symbol: "flame.fill", colorHex: "FF7043"),
        HabitPreset(name: "Hit protein goal", category: "Health & Fitness", symbol: "fish.fill", colorHex: "5E9FE8"),
        HabitPreset(name: "Take vitamins", category: "Health & Fitness", symbol: "pills.fill", colorHex: "B478F5"),
        HabitPreset(name: "Take medication", category: "Health & Fitness", symbol: "cross.case.fill", colorHex: "F45F6D"),
        HabitPreset(name: "Sleep 8 hours", category: "Health & Fitness", symbol: "bed.double.fill", colorHex: "777BEB"),
        HabitPreset(name: "Go to bed on time", category: "Health & Fitness", symbol: "moon.zzz.fill", colorHex: "6875D8"),
        HabitPreset(name: "Wake up early", category: "Health & Fitness", symbol: "sunrise.fill", colorHex: "FFAA42"),

        HabitPreset(name: "Meditate", category: "Mental Health & Mindfulness", symbol: "figure.mind.and.body", colorHex: "9B6DFF"),
        HabitPreset(name: "Journal", category: "Mental Health & Mindfulness", symbol: "book.closed.fill", colorHex: "DB8C58"),
        HabitPreset(name: "Practice gratitude", category: "Mental Health & Mindfulness", symbol: "heart.text.square.fill", colorHex: "F17AA4"),
        HabitPreset(name: "Pray", category: "Mental Health & Mindfulness", symbol: "hands.sparkles.fill", colorHex: "D6B05E"),
        HabitPreset(name: "Breathing exercises", category: "Mental Health & Mindfulness", symbol: "wind", colorHex: "56C6D8"),
        HabitPreset(name: "Spend time outside", category: "Mental Health & Mindfulness", symbol: "tree.fill", colorHex: "46B774"),
        HabitPreset(name: "Get sunlight", category: "Mental Health & Mindfulness", symbol: "sun.max.fill", colorHex: "FFBD3D"),
        HabitPreset(name: "Take a break", category: "Mental Health & Mindfulness", symbol: "cup.and.saucer.fill", colorHex: "C482E8"),
        HabitPreset(name: "Practice mindfulness", category: "Mental Health & Mindfulness", symbol: "sparkles", colorHex: "D07BDF"),
        HabitPreset(name: "No complaining", category: "Mental Health & Mindfulness", symbol: "bubble.left.and.bubble.right.fill", colorHex: "6C91D9"),
        HabitPreset(name: "Positive self-talk", category: "Mental Health & Mindfulness", symbol: "quote.bubble.fill", colorHex: "EF8DA8"),
        HabitPreset(name: "Therapy/self-reflection", category: "Mental Health & Mindfulness", symbol: "brain.head.profile", colorHex: "8B79E5"),
        HabitPreset(name: "Relax without screens", category: "Mental Health & Mindfulness", symbol: "iphone.slash", colorHex: "6275D8"),

        HabitPreset(name: "Plan the day", category: "Productivity", symbol: "calendar", colorHex: "5289F5"),
        HabitPreset(name: "Complete top priority", category: "Productivity", symbol: "target", colorHex: "F0646B"),
        HabitPreset(name: "Deep work", category: "Productivity", symbol: "timer", colorHex: "607BDE"),
        HabitPreset(name: "Work on personal project", category: "Productivity", symbol: "hammer.fill", colorHex: "DF8B47"),
        HabitPreset(name: "Study", category: "Productivity", symbol: "graduationcap.fill", colorHex: "7F74D9"),
        HabitPreset(name: "Read", category: "Productivity", symbol: "book.fill", colorHex: "D6994F"),
        HabitPreset(name: "Write", category: "Productivity", symbol: "pencil", colorHex: "E875A0"),
        HabitPreset(name: "Practice a skill", category: "Productivity", symbol: "scope", colorHex: "48A8C7"),
        HabitPreset(name: "Learn something new", category: "Productivity", symbol: "lightbulb.fill", colorHex: "F2B93B"),
        HabitPreset(name: "Review goals", category: "Productivity", symbol: "chart.line.uptrend.xyaxis", colorHex: "49BD8A"),
        HabitPreset(name: "Make to-do list", category: "Productivity", symbol: "checklist", colorHex: "5D91E9"),
        HabitPreset(name: "Clear inbox", category: "Productivity", symbol: "tray.fill", colorHex: "7186A8"),
        HabitPreset(name: "Clean workspace", category: "Productivity", symbol: "desktopcomputer", colorHex: "55AFC0"),
        HabitPreset(name: "No procrastinating", category: "Productivity", symbol: "hourglass", colorHex: "E28350"),
        HabitPreset(name: "Pomodoro sessions", category: "Productivity", symbol: "timer", colorHex: "EF665C"),
        HabitPreset(name: "Track work hours", category: "Productivity", symbol: "clock.fill", colorHex: "6488D9"),

        HabitPreset(name: "Limit screen time", category: "Digital Habits", symbol: "hourglass", colorHex: "7A72D6"),
        HabitPreset(name: "No social media", category: "Digital Habits", symbol: "person.2.slash", colorHex: "E46E7A"),
        HabitPreset(name: "Limit social media", category: "Digital Habits", symbol: "bubble.left.and.bubble.right.fill", colorHex: "627FCB"),
        HabitPreset(name: "No phone after bedtime", category: "Digital Habits", symbol: "moon.zzz.fill", colorHex: "666BD0"),
        HabitPreset(name: "No phone after waking up", category: "Digital Habits", symbol: "sunrise.fill", colorHex: "EBA84A"),
        HabitPreset(name: "No YouTube", category: "Digital Habits", symbol: "play.slash.fill", colorHex: "EC5A5A"),
        HabitPreset(name: "No gaming", category: "Digital Habits", symbol: "gamecontroller.fill", colorHex: "8B65D6"),
        HabitPreset(name: "Limit gaming", category: "Digital Habits", symbol: "gamecontroller.fill", colorHex: "6683DA"),
        HabitPreset(name: "No doomscrolling", category: "Digital Habits", symbol: "hand.raised.fill", colorHex: "D47761"),
        HabitPreset(name: "Unplug for an hour", category: "Digital Habits", symbol: "wifi.slash", colorHex: "55AC9D"),

        HabitPreset(name: "No sugar", category: "Food & Substance Habits", symbol: "cube.transparent.fill", colorHex: "6C9ED5"),
        HabitPreset(name: "No junk food", category: "Food & Substance Habits", symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: "E77A5C"),
        HabitPreset(name: "No fast food", category: "Food & Substance Habits", symbol: "fork.knife", colorHex: "D96A58"),
        HabitPreset(name: "No soda", category: "Food & Substance Habits", symbol: "cup.and.saucer.fill", colorHex: "5EA8D8"),
        HabitPreset(name: "No alcohol", category: "Food & Substance Habits", symbol: "wineglass.fill", colorHex: "A468C2"),
        HabitPreset(name: "No smoking", category: "Food & Substance Habits", symbol: "smoke.fill", colorHex: "8D929B"),
        HabitPreset(name: "No vaping", category: "Food & Substance Habits", symbol: "wind", colorHex: "65B6BB"),
        HabitPreset(name: "No caffeine", category: "Food & Substance Habits", symbol: "cup.and.saucer.fill", colorHex: "9C7657"),
        HabitPreset(name: "Limit caffeine", category: "Food & Substance Habits", symbol: "mug.fill", colorHex: "C88D5B"),
        HabitPreset(name: "No late-night eating", category: "Food & Substance Habits", symbol: "moon.fill", colorHex: "706FCB"),
        HabitPreset(name: "No snacking", category: "Food & Substance Habits", symbol: "hand.raised.fill", colorHex: "5DAE8B"),
        HabitPreset(name: "Intermittent fasting", category: "Food & Substance Habits", symbol: "clock.fill", colorHex: "6094D4"),
        HabitPreset(name: "Cook at home", category: "Food & Substance Habits", symbol: "frying.pan.fill", colorHex: "E98B47"),
        HabitPreset(name: "Meal prep", category: "Food & Substance Habits", symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: "53B77A"),

        HabitPreset(name: "Brush teeth", category: "Personal Care", symbol: "mouth.fill", colorHex: "55B8DC"),
        HabitPreset(name: "Floss", category: "Personal Care", symbol: "mouth.fill", colorHex: "65A4E3"),
        HabitPreset(name: "Skincare", category: "Personal Care", symbol: "face.smiling", colorHex: "E989AE"),
        HabitPreset(name: "Shower", category: "Personal Care", symbol: "shower.fill", colorHex: "4FAFD1"),
        HabitPreset(name: "Make bed", category: "Personal Care", symbol: "bed.double.fill", colorHex: "7C75CB"),
        HabitPreset(name: "Grooming", category: "Personal Care", symbol: "person.crop.circle.fill", colorHex: "6DA7A2"),
        HabitPreset(name: "Take supplements", category: "Personal Care", symbol: "pills.fill", colorHex: "AA79D8"),
        HabitPreset(name: "Drink less alcohol", category: "Personal Care", symbol: "wineglass.fill", colorHex: "B469B8"),
        HabitPreset(name: "Maintain bedtime routine", category: "Personal Care", symbol: "moon.zzz.fill", colorHex: "656FD0"),

        HabitPreset(name: "Clean", category: "Home & Life", symbol: "sparkles", colorHex: "55B8CF"),
        HabitPreset(name: "Tidy room", category: "Home & Life", symbol: "house.fill", colorHex: "67B986"),
        HabitPreset(name: "Do dishes", category: "Home & Life", symbol: "sink.fill", colorHex: "55A6CF"),
        HabitPreset(name: "Laundry", category: "Home & Life", symbol: "washer.fill", colorHex: "8679D9"),
        HabitPreset(name: "Declutter", category: "Home & Life", symbol: "shippingbox.fill", colorHex: "C18D56"),
        HabitPreset(name: "Water plants", category: "Home & Life", symbol: "leaf.fill", colorHex: "53B96E"),
        HabitPreset(name: "Check finances", category: "Home & Life", symbol: "dollarsign.circle.fill", colorHex: "48B987"),
        HabitPreset(name: "Track spending", category: "Home & Life", symbol: "creditcard.fill", colorHex: "5E8EE0"),
        HabitPreset(name: "Save money", category: "Home & Life", symbol: "banknote.fill", colorHex: "53B980"),

        HabitPreset(name: "Call family/friends", category: "Relationships & Personal Growth", symbol: "phone.fill", colorHex: "59A9E3"),
        HabitPreset(name: "Spend quality time with partner", category: "Relationships & Personal Growth", symbol: "heart.fill", colorHex: "F16F91"),
        HabitPreset(name: "Practice an instrument", category: "Relationships & Personal Growth", symbol: "music.note", colorHex: "A875DA"),
        HabitPreset(name: "Learn a language", category: "Relationships & Personal Growth", symbol: "character.bubble.fill", colorHex: "4FAFA6")
    ]

    static let categories = Array(Set(all.map(\.category))).sorted()

    static func preset(for name: String) -> HabitPreset? {
        all.first { $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
    }

    static func availableSymbol(for preset: HabitPreset) -> String {
        if UIImage(systemName: preset.symbol) != nil { return preset.symbol }

        let fallback: String
        switch preset.category {
        case "Health & Fitness": fallback = "heart.fill"
        case "Mental Health & Mindfulness": fallback = "brain.head.profile"
        case "Productivity": fallback = "checklist"
        case "Digital Habits": fallback = "bell.slash.fill"
        case "Food & Substance Habits": fallback = "fork.knife"
        case "Personal Care": fallback = "sparkles"
        case "Home & Life": fallback = "house.fill"
        default: fallback = "person.2.fill"
        }
        return UIImage(systemName: fallback) == nil ? "star.fill" : fallback
    }
}
