// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgenticInference",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AgenticInference",
            targets: [
                "AgenticInference",
            ]
        ),
        .executable(
            name: "ainftest",
            targets: [
                "AgenticInferenceTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Agentic.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Macros.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "AgenticInference",
            dependencies: [
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "Schema",
                    package: "Schema"
                ),
                .product(
                    name: "Macros",
                    package: "Macros"
                ),
            ]
        ),
        .executableTarget(
            name: "AgenticInferenceTestFlows",
            dependencies: [
                "AgenticInference",
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
