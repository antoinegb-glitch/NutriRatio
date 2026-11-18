// swift-tools-version: 5.9
// Ce paquet ne sert qu'à exécuter les tests de la logique pure sur le Mac
// (`swift test`), sans simulateur iOS. L'app elle-même se construit avec
// NutriRatio.xcodeproj (généré par `xcodegen`).
import PackageDescription

let package = Package(
    name: "NutriRatio",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(
            name: "NutriRatio",
            path: "NutriRatio",
            exclude: ["Views", "ViewModels", "Resources", "NutriRatioApp.swift"],
            sources: ["Models", "Scoring", "Parsing", "Services", "Recipes"]
        ),
        .testTarget(
            name: "NutriRatioTests",
            dependencies: ["NutriRatio"],
            path: "NutriRatioTests",
            resources: [.process("Fixtures")]
        ),
    ]
)
