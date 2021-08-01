# TestEnv

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


This is a 1-function package: `TestEnv.activate()`.

Consider this package has as a test-only dependency of **ChainRulesCore.jl**.
Not a main dependency

```julia
julia> using TestEnv;

julia> TestEnv.activate();

julia> using ChainRulesCore
```

You can also pass in the name of a package, to activate that package and it's test dependencies:
`TestEnv.activate("Javis")` for example would activate Javis.jl's test environment.

Finally you can pass in a function to run in this environment.
```julia
using TestEnv, ReTest
TestEnv.activate("Example") do
    retest()
end
```

## Where is the code?
The astute reader has probably notice that the default branch of this git repo is basically empty.
This is because we keep all the code in other branches.
One per minor release: `release-1.0`, `release-1.1` etc.
We do this because TestEnv.jl accesses a whole ton of interals of [Pkg](https://github.com/JuliaLang/Pkg.jl).
These internals change basically every single release.
Maintaining compatibility in a single branch for multiple julia versions leads to code that is a nightmare.
As such, we instead maintain 1 branch per julia minor version.
And we tag releases off that branch with major and minor versions matching the julia version supported, but with patch versions allowed to change freely.

 - [release-1.0](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.0) contains the code to support julia v1.0.x
 - [release-1.1](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.1) contains the code to support julia v1.1.x
 - release-1.2 does not exist yet, as we do not yet support julia 1.2
 - [release-1.3](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.3) contains the code to support julia v1.3.x
 - [release-1.4](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.4) contains the code to support julia v1.4.x, 1.5.x, 1.6.x
    - This branch is notably weird, because this is where we started and we tried to maintain support for multiple versions in 1 branch.
    - It also contains code that almost works for all version from 1.0-1.7.
    - In the future, we might move 1.5 and 1.6 support to their own branches, but so far they work were they are, and so far haven't needed maintainance.
 - [release-1.7](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.7) contains the code to support julia v1.7.x
 - [release-1.8](https://github.com/JuliaTesting/TestEnv.jl/tree/release-1.8) contains the code to support julia v1.8.x


**Do not make PRs against this branch.**
Except to update this README.
Instread you probably want to PR a branch for some current version of Julia.

This is a bit weird for semver.
New features *can* be added in patch release, but they must be ported to all later branches, and patch releases must be made there also.
For the this reason: we *only* support the latest patch release of any branch.
Older ones may be yanked if they start causing issues for people.
