import Foundation

public enum HabitIconGlyph {
    // Stable identifiers keep custom pictograms portable through backups and widgets.
    public static let icons: [String: (glyph: String, title: String, keywords: String)] = [
        "custom:smoking": ("🚬", "Smoking", "cigarette nicotine tobacco addiction"),
        "custom:vaping": ("🌫️", "Vaping", "vape smoke nicotine addiction"),
        "custom:drugs": ("💊", "Drugs", "pills medication substance addiction"),
        "custom:needle": ("💉", "Needle", "syringe drugs injection"),
        "custom:cannabis": ("🌿", "Cannabis", "weed marijuana herb drugs"),
        "custom:alcohol": ("🍷", "Alcohol", "wine drinking addiction"),
        "custom:beer": ("🍺", "Beer", "drinking alcohol addiction"),
        "custom:gambling": ("🎰", "Gambling", "casino betting slots addiction"),
        "custom:dice": ("🎲", "Dice", "gambling betting risk"),
        "custom:chains": ("⛓️", "Chains", "bondage addiction trapped habit"),
        "custom:skull": ("💀", "Skull", "danger death bad"),
        "custom:poison": ("☠️", "Poison", "toxic danger skull"),
        "custom:devil": ("😈", "Temptation", "devil evil sin"),
        "custom:anger": ("😡", "Anger", "rage temper hate"),
        "custom:swearing": ("🤬", "Swearing", "cursing anger profanity"),
        "custom:laziness": ("🦥", "Laziness", "sloth procrastination"),
        "custom:lust": ("❤️‍🔥", "Lust", "temptation desire pornography porn"),
        "custom:money": ("💸", "Overspending", "shopping money greed debt"),
        "custom:junkfood": ("🍔", "Junk food", "overeating fast food diet"),
        "custom:sugar": ("🍬", "Sugar", "sweets candy addiction"),
        "custom:tv": ("📺", "Television", "entertainment binge watching"),
        "custom:brainwashed-tv": ("📺🧠", "Brainwashed TV", "entertainment media mind brainwash"),
        "custom:zombie": ("🧟", "Zombie", "mindless entertainment scrolling addiction"),
        "custom:brain": ("🧠", "Brain", "mind focus brainwashed"),
        "custom:spiral": ("😵‍💫", "Doomscrolling", "social media spiral overwhelmed addiction"),
        "custom:phone": ("📱", "Social media", "phone internet screen scrolling addiction"),
        "custom:messages": ("💬", "Messages", "chat social media texting"),
        "custom:likes": ("👍", "Likes", "social media approval validation"),
        "custom:selfie": ("🤳", "Selfies", "social media vanity"),
        "custom:gaming": ("🎮", "Gaming", "videogame entertainment addiction"),
        "custom:videos": ("🎬", "Videos", "shorts reels youtube movies entertainment"),
        "custom:notifications": ("🔔", "Notifications", "distraction phone social media"),
        "custom:cross": ("✝️", "Christian cross", "jesus christ faith god christianity"),
        "custom:orthodox-cross": ("☦️", "Orthodox cross", "christian jesus faith"),
        "custom:prayer": ("🙏", "Prayer", "pray god christian faith worship"),
        "custom:bible": ("📖", "Bible", "scripture gospel reading word christian"),
        "custom:church": ("⛪", "Church", "christian worship fellowship"),
        "custom:dove": ("🕊️", "Dove", "holy spirit peace christian"),
        "custom:candle": ("🕯️", "Candle", "prayer light christian"),
        "custom:fish": ("🐟", "Fish", "ichthys jesus christian"),
        "custom:bread": ("🍞", "Bread", "communion daily bread christian"),
        "custom:chalice": ("🍷", "Chalice", "communion christian cup"),
        "custom:crown": ("👑", "Crown", "christ king kingdom christian"),
        "custom:lamb": ("🐑", "Lamb", "lamb of god jesus christian"),
        "custom:sword": ("🗡️", "Sword", "sword of the spirit bible christian"),
        "custom:shield": ("🛡️", "Shield", "shield of faith armor god christian"),
        "custom:light": ("🌅", "New dawn", "resurrection hope christian light"),
        "custom:heart": ("❤️", "Love", "charity love christian compassion"),
        "custom:help": ("🤝", "Serve others", "help charity fellowship christian")
    ]

    public static func title(for identifier: String) -> String {
        icons[identifier]?.title ?? identifier.replacingOccurrences(of: ".", with: " ")
    }

    public static func matches(_ identifier: String, query: String) -> Bool {
        let icon = icons[identifier]
        return [identifier, icon?.title ?? "", icon?.keywords ?? ""].joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
    }
}

#if canImport(SwiftUI)
import SwiftUI

public struct HabitSymbol: View {
    public let name: String
    public init(_ name: String) { self.name = name }
    public var body: some View {
        Group {
            if let icon = HabitIconGlyph.icons[name] {
                Text(icon.glyph).lineLimit(1).minimumScaleFactor(0.5)
            } else {
                Image(systemName: name)
            }
        }
        .accessibilityLabel(HabitIconGlyph.title(for: name))
    }
}
#endif
