# TestEnv

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


This is a 1-function package: `TestEnv.activate`.
It lets you activate the test environment from a given package.
Why is this useful?

This lets you run code in the test enviroment, interactively; giving you access to all your test-only dependencies.
When you run `]test` in the REPL, a new Julia process is started which activates a temporary environment containing the tested package together with all its test-only dependencies.
These can be either defined in the `[extras]` section in the package's `Project.toml` or in a separate `test/Project.toml`.
The special temporary environment is different than the plain package environment (which doesn't contain the extra test dependencies) or the `test/Project.toml` environment (which doesn't contain the package itself, and may not exist).
Once the tests finish, the extra Julia process is closed and the temporary environment is deleted.
You are not able to manually run any other code in it, which would be useful for test writing and debugging.
Julia does not offer an official mechanism to activate such an environment outside of `]test`.
That's what `TestEnv.activate()` is for.

## Note on installation:
Like other developer focused tools, TestEnv.jl should not be added as a dependency of the package you are developing, but rather added to your global enviroment, so it is always available.

## Example

Consider **ChainRules.jl** which has a test-only dependency of **ChainRulesTestUtils.jl**,
not a main dependency.

(Note that you can install `TestEnv` in your global environment as it has no dependencies other than `Pkg`.
This way you can load it from anywhere, instead of having to add it to package environments.)

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
