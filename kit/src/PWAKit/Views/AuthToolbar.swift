import SwiftUI
import UIKit

// MARK: - AuthToolbar

/// A toolbar view for auth origin navigation.
///
/// `AuthToolbar` provides a "Done" button that allows users to dismiss
/// OAuth or authentication flows and return to the main app. This toolbar
/// is displayed when the WebView navigates to an auth origin.
///
/// ## Usage
///
/// The toolbar should be displayed conditionally based on whether the
/// current WebView URL is an auth origin:
///
/// ```swift
/// struct ContentView: View {
///     @State private var showAuthToolbar = false
///     var onDismiss: () -> Void
///
///     var body: some View {
///         VStack(spacing: 0) {
///             if showAuthToolbar {
///                 AuthToolbar(onDone: onDismiss)
///             }
///             WebViewContainer(...)
///         }
///     }
/// }
/// ```
///
/// ## Behavior
///
/// When the "Done" button is tapped, the `onDone` closure is called.
/// The parent view should handle navigating back to the start URL:
///
/// ```swift
/// AuthToolbar(onDone: {
///     webView?.load(URLRequest(url: startURL))
/// })
/// ```
public struct AuthToolbar: View {
    // MARK: Lifecycle

    /// Creates an auth toolbar.
    ///
    /// - Parameter onDone: Callback invoked when the Done button is tapped.
    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    // MARK: Public

    public var body: some View {
        AuthToolbarRepresentable(onDone: onDone)
            .frame(height: 44)
    }

    // MARK: Private

    /// Callback invoked when the Done button is tapped.
    private let onDone: () -> Void
}

// MARK: - AuthToolbarRepresentable

/// UIViewRepresentable wrapper for UIToolbar.
///
/// This provides a native UIToolbar appearance that matches iOS system design.
private struct AuthToolbarRepresentable: UIViewRepresentable {
    // MARK: - Coordinator

    final class Coordinator: NSObject {
        // MARK: Lifecycle

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        // MARK: Internal

        var onDone: () -> Void

        @objc func doneTapped() {
            onDone()
        }
    }

    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.barTintColor = .systemBackground
        toolbar.isTranslucent = true

        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        let doneButton = UIBarButtonItem(
            title: NSLocalizedString("Done", comment: "Auth toolbar Done button"),
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )

        toolbar.items = [flexibleSpace, doneButton]
        return toolbar
    }

    func updateUIView(_: UIToolbar, context: Context) {
        // Update coordinator callback if needed
        context.coordinator.onDone = onDone
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
    struct AuthToolbar_Previews: PreviewProvider {
        static var previews: some View {
            VStack {
                AuthToolbar(onDone: {
                    print("Done tapped")
                })
                Spacer()
            }
        }
    }
#endif
