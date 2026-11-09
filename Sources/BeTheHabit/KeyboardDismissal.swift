import SwiftUI
import UIKit

/// Closes the keyboard when a tap lands outside a text input, anywhere in the window.
/// Sheets share the window, so one recognizer covers them too. Other taps still go through.
@MainActor
final class KeyboardDismissTap: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTap()
    private var keyboardIsVisible = false
    private var observers: [NSObjectProtocol] = []

    func install() {
        if observers.isEmpty {
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated { KeyboardDismissTap.shared.keyboardIsVisible = true }
                },
                center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated { KeyboardDismissTap.shared.keyboardIsVisible = false }
                },
            ]
        }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows where !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === self }) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Stay out of every other gesture, such as holding a habit to reorder it, unless there's a keyboard to close.
        guard keyboardIsVisible else { return false }

        // Closing the keyboard moves an alert mid-tap, which loses the tap on its button.
        var top = (gestureRecognizer.view as? UIWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if top is UIAlertController { return false }

        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

extension View {
    /// Closes the keyboard on scroll and adds a Done button above it, which the number pad needs.
    func keyboardDismissal() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}
