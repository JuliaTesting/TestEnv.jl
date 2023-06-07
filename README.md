# TestEnv

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

This repository contains the TestEnv package, which provides a single function called `TestEnv.activate`. This function allows you to activate the test environment of a given package, similar to how `Pkg.activate` activates its main environment.

For instance, if you want to activate the test environment for ChainRules.jl, which has a test-only dependency on ChainRulesTestUtils.jl, you can use the following commands:

```julia
pkg> activate ~/.julia/dev/ChainRules

julia> using TestEnv;

julia> TestEnv.activate();

julia> using ChainRulesTestUtils
```

Use `Pkg.activate` to re-activate the previous environment, e.g. `Pkg.activate("~/.julia/dev/ChainRules")`.

You can also pass in the name of a package, to activate that package and it's test dependencies:
`TestEnv.activate("Javis")` for example would activate Javis.jl's test environment.

Additionally, you can pass a function to run in this environment using the `TestEnv.activate` block syntax:
```julia
using TestEnv, ReTest
TestEnv.activate("Example") do
    retest()
end
```

## Where is the code?
The repository structure of the TestEnv package follows a specific approach to handle the evolving internals of Pkg and maintain compatibility across different Julia versions. The default branch of this repository is intentionally empty, as the code resides in separate branches dedicated to each minor release. This allows us to adapt to the frequent changes in [Pkg](https://github.com/JuliaLang/Pkg.jl) internals, ensuring a better code maintenance experience. The name of each branch corresponds to the Julia version it supports, such as release-1.0, release-1.1, etc. The following branches are available:

The default branch of this repository appears to be empty. This is because the code is stored in separate branches, one for each minor release version of Julia. Each branch is named `release-x.y`, corresponding to the supported Julia version.

We do this because TestEnv.jl accesses a ton of internals of [Pkg](https://github.com/JuliaLang/Pkg.jl), which are subject to change every single release.
Maintaining compatibility in a single branch for multiple Julia versions leads to nightmarish code.
As such, we instead maintain one branch per Julia minor version.
And we tag releases off that branch with major and minor versions matching the Julia version supported, but with patch versions allowed to change freely.

 - [release-1.0](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.0) supports Julia v1.0.x
 - [release-1.1](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.1) supports Julia v1.1.x
 - [release-1.2](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.2) supports Julia v1.2.x
 - [release-1.3](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.3) supports Julia v1.3.x
 - [release-1.4](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.4) supports Julia 1.4.x, v1.5.x, and v1.6.x
    - This period experienced a rare golden age where the internals of Pkg remained unchanged for almost a year.
 - [release-1.7](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.7) supports Julia v1.7.x
 - [release-1.8](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.8) supports Julia v1.8.x and v1.9.x
    - Another period of stability when the internals of Pkg didn't change. Long may it continue.
 - [release-1.10](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.10) supports Julia v1.10.x

Please refrain from submitting pull requests against the default branch except for updating this README. Instead, we recommend creating a new branch specific to the desired Julia version you are working with.

It's worth noting that the versioning approach for TestEnv follows a slightly different pattern compared to semantic versioning. While new features can be added in patch releases, they must be ported to all subsequent branches, and patch releases must be made accordingly. As a result, TestEnv only supports the latest patch release of any branch. If older branches start causing issues, they  may be subject to removal to ensure a smooth user experience.

Feel free to explore and contribute to the appropriate branch for your desired Julia version.

## Specifying Compatibility in Project.toml

If you are using TestEnv as a dependency for a package that supports multiple versions of Julia, you might be wondering how to specify compatibility in your Project.toml's [compat] section. Don't worry; the package manager has got you covered.

To ensure compatibility with TestEnv, you can use any of the following syntaxes in your [compat] section:

- `TestEnv = 1`
- `TestEnv = 1.0`
- `TestEnv = 1.0.0`
- `TestEnv = ^1`
- `TestEnv = ^1.0`
- `TestEnv = ^1.0.0`

By using one of these syntaxes, the package manager can choose the appropriate minor version of TestEnv that is compatible with the currently loaded version of Julia. It will select a version `v` satisfying the condition `1.0.0 <= v < 2.0.0`.

This flexibility allows you to easily handle compatibility with TestEnv while supporting different versions of Julia in your package.

### See also:
 - [Discourse Release Announcement](https://discourse.julialang.org/t/ann-testenv-jl-activate-your-test-enviroment-so-you-can-use-your-test-dependencies/65739)
