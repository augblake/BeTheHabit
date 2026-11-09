import Foundation

public enum HabitIconGlyph {
    // Stable custom: identifiers keep names and search terms, and draw a monochrome system symbol.
    public static let icons: [String: (symbol: String, title: String, keywords: String)] = [
        "custom:smoking": ("smoke.fill", "Smoking", "cigarette nicotine tobacco addiction"),
        "custom:vaping": ("wind", "Vaping", "vape smoke nicotine addiction"),
        "custom:drugs": ("pills.fill", "Drugs", "pills medication substance addiction"),
        "custom:needle": ("syringe.fill", "Needle", "syringe drugs injection"),
        "custom:cannabis": ("leaf.fill", "Cannabis", "weed marijuana herb drugs"),
        "custom:alcohol": ("wineglass.fill", "Alcohol", "wine drinking addiction"),
        "custom:beer": ("mug.fill", "Beer", "drinking alcohol addiction"),
        "custom:gambling": ("suit.spade.fill", "Gambling", "casino betting slots addiction"),
        "custom:dice": ("dice.fill", "Dice", "gambling betting risk"),
        "custom:chains": ("link", "Chains", "bondage addiction trapped habit"),
        "custom:skull": ("xmark.octagon.fill", "Skull", "danger death bad"),
        "custom:poison": ("exclamationmark.triangle.fill", "Poison", "toxic danger skull"),
        "custom:devil": ("exclamationmark.shield.fill", "Temptation", "devil evil sin"),
        "custom:anger": ("flame.fill", "Anger", "rage temper hate"),
        "custom:swearing": ("exclamationmark.bubble.fill", "Swearing", "cursing anger profanity"),
        "custom:laziness": ("bed.double.fill", "Laziness", "sloth procrastination"),
        "custom:lust": ("flame.circle.fill", "Lust", "temptation desire pornography porn"),
        "custom:money": ("banknote.fill", "Overspending", "shopping money greed debt"),
        "custom:junkfood": ("takeoutbag.and.cup.and.straw.fill", "Junk food", "overeating fast food diet"),
        "custom:sugar": ("birthday.cake.fill", "Sugar", "sweets candy addiction"),
        "custom:tv": ("tv.fill", "Television", "entertainment binge watching"),
        "custom:brainwashed-tv": ("tv", "Brainwashed TV", "entertainment media mind brainwash"),
        "custom:zombie": ("figure.walk", "Zombie", "mindless entertainment scrolling addiction"),
        "custom:brain": ("brain.head.profile", "Brain", "mind focus brainwashed"),
        "custom:spiral": ("hurricane", "Doomscrolling", "social media spiral overwhelmed addiction"),
        "custom:phone": ("iphone", "Social media", "phone internet screen scrolling addiction"),
        "custom:messages": ("bubble.left.fill", "Messages", "chat social media texting"),
        "custom:likes": ("hand.thumbsup.fill", "Likes", "social media approval validation"),
        "custom:selfie": ("camera.fill", "Selfies", "social media vanity"),
        "custom:gaming": ("gamecontroller.fill", "Gaming", "videogame entertainment addiction"),
        "custom:videos": ("play.rectangle.fill", "Videos", "shorts reels youtube movies entertainment"),
        "custom:notifications": ("bell.fill", "Notifications", "distraction phone social media"),
        "custom:cross": ("cross.fill", "Christian cross", "jesus christ faith god christianity"),
        "custom:orthodox-cross": ("cross", "Orthodox cross", "christian jesus faith"),
        "custom:prayer": ("hands.sparkles.fill", "Prayer", "pray god christian faith worship"),
        "custom:bible": ("book.fill", "Bible", "scripture gospel reading word christian"),
        "custom:church": ("building.columns.fill", "Church", "christian worship fellowship"),
        "custom:dove": ("bird.fill", "Dove", "holy spirit peace christian"),
        "custom:candle": ("flame", "Candle", "prayer light christian"),
        "custom:fish": ("fish.fill", "Fish", "ichthys jesus christian"),
        "custom:bread": ("fork.knife", "Bread", "communion daily bread christian"),
        "custom:chalice": ("wineglass", "Chalice", "communion christian cup"),
        "custom:crown": ("crown.fill", "Crown", "christ king kingdom christian"),
        "custom:lamb": ("pawprint.fill", "Lamb", "lamb of god jesus christian"),
        "custom:sword": ("shield.lefthalf.filled", "Sword", "sword of the spirit bible christian"),
        "custom:shield": ("shield.fill", "Shield", "shield of faith armor god christian"),
        "custom:light": ("sunrise.fill", "New dawn", "resurrection hope christian light"),
        "custom:heart": ("heart.fill", "Love", "charity love christian compassion"),
        "custom:help": ("hands.clap.fill", "Serve others", "help charity fellowship christian")
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
        Image(systemName: HabitIconGlyph.icons[name]?.symbol ?? name)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary)
            .accessibilityLabel(HabitIconGlyph.title(for: name))
    }
}
#endif
