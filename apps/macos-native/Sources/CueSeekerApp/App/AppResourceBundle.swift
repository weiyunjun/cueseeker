import Foundation

private final class AppResourceBundleToken {}

extension Bundle {
    /// The resource bundle containing CueSeekerApp's localized strings and assets.
    ///
    /// SwiftPM's auto-generated `Bundle.module` assumes a command-line tool layout
    /// and checks only the bundle root or developer build-time paths. In a standard
    /// macOS `.app` bundle, resources reside in `Contents/Resources`. This accessor
    /// checks standard macOS app bundle resources first to prevent fatal errors when
    /// the app is launched on an independent system, while preserving support for
    /// local test and development runners.
    static let appResources: Bundle = {
        let bundleName = "CueSeekerNative_CueSeekerApp"

        // 1. Standard macOS .app bundle structure: Contents/Resources/CueSeekerNative_CueSeekerApp.bundle
        if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL) {
            return bundle
        }

        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("\(bundleName).bundle"),
           let bundle = Bundle(url: resourceURL) {
            return bundle
        }

        // 2. Token class bundle search (works when hosted in an app or framework)
        let tokenBundle = Bundle(for: AppResourceBundleToken.self)
        if let bundleURL = tokenBundle.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL) {
            return bundle
        }

        // 3. Sibling or container search (works in swift test and local debug executables)
        let candidateRoots = [
            Bundle.main.bundleURL,
            tokenBundle.bundleURL.deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent()
        ]
        for root in candidateRoots {
            let candidateURL = root.appendingPathComponent("\(bundleName).bundle")
            if let bundle = Bundle(url: candidateURL) {
                return bundle
            }
        }

        // 4. Search all loaded bundles
        for candidate in Bundle.allBundles {
            if let bundleURL = candidate.url(forResource: bundleName, withExtension: "bundle"),
               let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        // 5. Fallback to Bundle.main
        return Bundle.main
    }()
}
