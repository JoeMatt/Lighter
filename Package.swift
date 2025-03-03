// swift-tools-version:6.0

import PackageDescription

var package = Package(
  name: "Lighter",

  platforms: [ .macOS(.v10_15), .iOS(.v13), .macCatalyst(.v13) ],
  
  products: [
    .library(name: "Lighter",         targets: [ "Lighter"       ]),
    .library(name: "SQLite3Schema",   targets: [ "SQLite3Schema" ]),

    .executable(name: "sqlite2swift", targets: [ "sqlite2swift"  ]),
    
    .plugin(name: "Enlighter",        targets: [ "Enlighter"     ]),
    .plugin(name: "Generate Code for SQLite",
            targets: [ "Generate Code for SQLite" ])
  ],
  
  targets: [
    // A small library used to fetch schema information from SQLite3 databases.
    .target(name: "SQLite3Schema", exclude: [ "README.md" ]),
    
    // Lighter is a shared lib providing common protocols used by Enlighter
    // generated models and such.
    // Note that Lighter isn't that useful w/o code generation (i.e. as a
    // standalone lib).
    .target(name: "Lighter"),


    // MARK: - Plugin Support
    
    // The CodeGenAST is a small and hacky helper lib that can format/render
    // Swift source code.
    .target(name    : "LighterCodeGenAST",
            path    : "Plugins/Libraries/LighterCodeGenAST",
            exclude : [ "README.md" ]),
    
    // This library contains all the code generation, to be used by different
    // clients.
    .target(name         : "LighterGeneration",
            dependencies : [ "LighterCodeGenAST", "SQLite3Schema" ],
            path         : "Plugins/Libraries/LighterGeneration",
            exclude      : [ "README.md", "LighterConfiguration/README.md" ]),

    
    // MARK: - Tests
    
    .testTarget(name: "CodeGenASTTests", dependencies: [ "LighterCodeGenAST" ]),
    .testTarget(name: "EntityGenTests",  dependencies: [ "LighterGeneration" ]),
    .testTarget(name: "LighterOperationGenTests",
                dependencies: [ "LighterGeneration" ]),
    .testTarget(name: "ContactsDatabaseTests", dependencies: [ "Lighter" ],
                exclude: [ "contacts-create.sql" ]),

    
    // MARK: - Plugins and supporting Tools

    .executableTarget(name         : "sqlite2swift",
                      dependencies : [ "LighterGeneration" ],
                      path         : "Plugins/Tools/sqlite2swift",
                      exclude      : [ "README.md" ]),

    .plugin(name: "Enlighter", capability: .buildTool(),
            dependencies: [ "sqlite2swift" ]),
    
    .plugin(
      name: "Generate Code for SQLite",
      capability: .command(
        intent: .custom(
          verb: "sqlite2swift",
          description:
            "Generate Swift code for SQLite DBs into the Sources directory."
          ),
          permissions: [
            .writeToPackageDirectory(reason:
              "The plugin needs access to generate the source file.")
          ]
      ),
      dependencies: [ "sqlite2swift" ],
      path: "Plugins/GenerateCodeForSQLite"
    ),

    
    // MARK: - Internal Plugin for Generating Variadics
    
    .executableTarget(name         : "GenerateInternalVariadics",
                      dependencies : [ "LighterGeneration" ],
                      path         : "Plugins/Tools/GenerateInternalVariadics",
                      exclude      : [ "README.md" ]),
    .plugin(
      name: "Generate Variadics into Lighter (Internal)",
      capability: .command(
        intent: .custom(
          verb: "write-internal-variadics",
          description:
            "Generate the variadic queries into the Sources/Lighter directory."
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "The plugin needs access to generate the source file.")
        ]
      ),
      dependencies: [ "GenerateInternalVariadics" ],
      path: "Plugins/WriteInternalVariadics"
    ),
    
    
    // MARK: - Environment specific tests
    .testTarget(name: "FiveThirtyEightTests",
                dependencies: [ "LighterGeneration" ]),
    .testTarget(name: "NorthwindTests",
                dependencies: [ "LighterGeneration" ])
  ],
  .swiftLanguageVersions: [ .v5, v6 ]
)

#if !(os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
package.products += [ .library(name: "SQLite3", targets: [ "SQLite3" ]) ]
package.targets += [
  .systemLibrary(name: "SQLite3",
                 path: "Sources/SQLite3-Linux",
                 providers: [ .apt(["libsqlite3-dev"]) ])
]
package.targets
  .first(where: { $0.name == "SQLite3Schema" })?
  .dependencies.append("SQLite3")
package.targets
  .first(where: { $0.name == "Lighter" })?
  .dependencies.append("SQLite3")
#endif // not-Darwin
