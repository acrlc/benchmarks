// swift-tools-version:5.5
import PackageDescription

let package = Package(
 name: "Benchmarks",
 platforms: [.macOS(.v10_15), .iOS(.v13)],
 products: [.library(name: "Benchmarks", targets: ["Benchmarks"])],
 dependencies: [
  .package(url: "https://github.com/acrlc/core.git", branch: "main"),
  .package(url: "https://github.com/acrlc/time.git", branch: "main")
 ],
 targets: [
  .target(
   name: "Benchmarks",
   dependencies: [
    .product(name: "Time", package: "time"),
    .product(name: "Core", package: "core"),
    .product(name: "Utilities", package: "core")
   ]
  ),
  .testTarget(name: "BenchmarksTests", dependencies: ["Benchmarks"])
 ]
)
