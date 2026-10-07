// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "H3Swift",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(name: "H3", targets: ["H3"]),
    ],
    targets: [
        // Vendored uber/h3 v4.4.1 C library.
        .target(
            name: "Ch3",
            path: "Sources/Ch3",
            sources: [
                "algos.c",
                "baseCells.c",
                "bbox.c",
                "coordijk.c",
                "directedEdge.c",
                "faceijk.c",
                "h3Assert.c",
                "h3Index.c",
                "iterators.c",
                "latLng.c",
                "linkedGeo.c",
                "localij.c",
                "mathExtensions.c",
                "polyfill.c",
                "polygon.c",
                "vec2d.c",
                "vec3d.c",
                "vertex.c",
                "vertexGraph.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("internal"),
                // Match Darwin's double constants before H3's #ifndef fallbacks.
                .define("M_PI", to: "3.14159265358979323846264338327950288"),
                .define("M_PI_2", to: "1.57079632679489661923132169163975144"),
            ]
        ),
        .target(name: "H3", dependencies: ["Ch3"]),
    ]
)
