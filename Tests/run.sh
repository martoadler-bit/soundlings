#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/soundlings-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
model=(Soundlings/World.swift Soundlings/BuilderModel.swift Soundlings/BuildTutorialPlan.swift)
scene=("${model[@]}" Soundlings/CharacterSpace.swift Soundlings/PortalTransition.swift Soundlings/FlightNavigation.swift Soundlings/GardenScene.swift Soundlings/VisualStyle.swift Soundlings/BuilderScene.swift Soundlings/EnvironmentScene.swift Soundlings/OceanMovie.swift Soundlings/BuildTutorialScene.swift)
swiftc -O -module-cache-path "$test_dir/cache" "${model[@]}" Soundlings/LoopRenderer.swift Tests/main.swift -o "$test_dir/audio"
"$test_dir/audio"
for suite in Scene Motion Features Builder Transitions Flight Mechanisms RandomMotion Tutorial Arches Visuals OceanVideo; do
    swiftc -O -module-cache-path "$test_dir/cache" "${scene[@]}" "Tests/$suite/main.swift" -o "$test_dir/$suite"
    "$test_dir/$suite"
done
swiftc -O -module-cache-path "$test_dir/cache" "${scene[@]}" Soundlings/LoopRenderer.swift Soundlings/Game.swift Soundlings/BuilderGame.swift Tests/Controller/Support.swift Tests/Controller/main.swift -o "$test_dir/controller"
"$test_dir/controller"
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios17.0-simulator -sdk "$sdk_path" -module-cache-path "$test_dir/ios-cache" Soundlings/*.swift
