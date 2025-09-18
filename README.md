[![Factorio Mod Portal page](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fkhaoslib&style=for-the-badge)](https://mods.factorio.com/mod/khaoslib) [![](https://img.shields.io/github/issues/QuingKhaos/khaoslib/bug?label=Bug%20Reports&style=for-the-badge)](https://github.com/QuingKhaos/khaoslib/issues?q=is%3Aissue%20state%3Aopen%20label%3Abug) [![](https://img.shields.io/github/issues-pr/QuingKhaos/khaoslib?label=Pull%20Requests&style=for-the-badge)](https://github.com/QuingKhaos/khaoslib/pulls) [![Ko-fi](https://img.shields.io/badge/Ko--fi-support%20me-hotpink?logo=kofi&logoColor=white&style=for-the-badge)](https://ko-fi.com/quingkhaos)

# QuingKhaos' Factorio Library

A set of commonly-used utilities by QuingKhaos for creating Factorio mods.

## Usage

Download the latest release from the [mod portal](https://mods.factorio.com/mod/khaoslib/downloads) or [GitHub releases](https://github.com/QuingKhaos/khaoslib/releases), unzip it and put it in your mods directory. You can access libraries provided by khaoslib with `require("__khaoslib__.libname")`.

Add the khaoslib directory to your language server's library. I recommend installing the [Factorio modding toolkit](https://github.com/justarandomgeek/vscode-factoriomod-debug) and setting it up with the [Sumneko Lua language server](https://github.com/sumneko/lua-language-server) to get cross-mod autocomplete and type checking.

## Stability guarantee

khaoslib follows [Semantic Versioning](https://semver.org/). Thus any 0.x API should not be considered stable. I will do my best to avoid breaking changes in minor releases, but if a breaking change is necessary it will be documented in the changelog.

## Legal notice

khaoslib is licensed under the LGPLv3, unlike my other mods which are all licensed under the GPLv3. Mods that use khaoslib are not required to be open source, nor are they required to be licensed under the LGPLv3. However, if you modify khaoslib itself and distribute the modified version, you must also distribute the source code of your modified version under the LGPLv3.
