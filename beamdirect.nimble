# Package

version     = "0.1.0"
author      = "Francis Thérien"
description = "Beam analysis"
license     = "All rights reserved"
skipDirs    = @["src"]

# Deps

requires "nim >= 1.0.0",
    "arraymancer >= 0.5.2",
    "samson >= 0.1.0"

task build_debug, "build":
    var switches = " -o:build/"
    exec "nim c" & switches & " src/beamdirect.nim"