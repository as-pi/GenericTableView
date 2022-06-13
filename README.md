# GenericTableView

## Introduction

Swift iOs TableView kit for simple work with UITableView. It supports horizontal and vertical cells, all cells support self-sizing. 

Example of usage also provided

### Installing from Xcode

Add a package by selecting `File` → `Add Packages…` in Xcode’s menu bar.

### Alternatively, add GenericTableView to a `Package.swift` manifest

To integrate via a `Package.swift` manifest instead of Xcode, you can add
Firebase to the dependencies array of your package:

```swift
dependencies: [
  .package(
    name: "GenericTableView",
    url: "https://github.com/as-pi/GenericTableView.git",
    .upToNextMajor(from: "0.0.1")
  ),

  // Any other dependencies you have...
],
```

Then, in any target that depends on a Firebase product, add it to the `dependencies`
array of that target:

```swift
.target(
  name: "MyTargetName",
  dependencies: [
    .product(name: "GenericTableView", package: "GenericTableView"),
  ]
),
```
