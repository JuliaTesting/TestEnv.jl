# TestEnv

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


This is a 1-function package: `TestEnv.activate`.
It lets you activate the test enviroment from a given package.
Just like `Pkg.activate` lets you activate it's main enviroment.


Consider for example **ChainRules.jl** has as a test-only dependency of **ChainRulesTestUtils.jl**,
not a main dependency

```julia
pkg> activate ~/.julia/dev/ChainRules

julia> using TestEnv;

julia> TestEnv.activate();

julia> using ChainRulesTestUtils
```

Use `Pkg.activate` to re-activate the previous environment, e.g. `Pkg.activate("~/.julia/dev/ChainRules")`.

You can also pass in the name of a package, to activate that package and it's test dependencies:
`TestEnv.activate("Javis")` for example would activate Javis.jl's test environment.

Finally you can pass in a function to run in this environment.
```julia
using TestEnv, ReTest
TestEnv.activate("Example") do
    retest()
end
```

### See also:
 - [Discourse Release Announcement](https://discourse.julialang.org/t/ann-testenv-jl-activate-your-test-enviroment-so-you-can-use-your-test-dependencies/65739)
