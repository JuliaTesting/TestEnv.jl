"""
    TestEnv.activate(f, [pkg])

Activate the test enviroment of `pkg` (defaults to current enviroment), and run `f()`,
then deactivate the enviroment.
This is not useful for many people: Julia is not really designed to have the enviroment
being changed while you are executing code.
However, this *is* useful for anyone doing something like making a alternative to
`Pkg.test()`.
Indeed this is basically extracted from what `Pkg.test()` does.
"""
function activate(f, pkg::AbstractString=current_pkg_name())
    pkgspec = deepcopy(PackageSpec(pkg))
    ctx = Context()
    isinstalled!(ctx, pkgspec) || throw(TestEnvError("$pkg not installed 👻"))
    Pkg.instantiate(ctx)
    return _sandbox(f, ctx, pkgspec)
end

"""
    TestEnv.activate([pkg])

Activate the test enviroment of `pkg` (defaults to current enviroment).
"""
function activate(pkg::AbstractString=current_pkg_name())
    pkgspec = deepcopy(PackageSpec(pkg))
    ctx = Context()
    isinstalled!(ctx, pkgspec) || throw(TestEnvError("$pkg not installed 👻"))
    Pkg.instantiate(ctx)
    return make_test_env(ctx, pkgspec)
end

current_pkg_name() = Context().env.pkg.name

"""
    isinstalled!(ctx::Context, pkgspec::Pkg.Types.PackageSpec)

Checks if the package is installed by using `ensure_resolved` from `Pkg/src/Types.jl`.
This function fails if the package is not installed, but here we wrap it in a
try-catch as we may want to test another package after the one that isn't installed.

For Julia versions V1.4 and later, the first arguments of the Pkg functions used
is of type `Pkg.Types.Context`. For earlier versions, they are of type
`Pkg.Types.EnvCache`.
"""
function isinstalled!(ctx::Context, pkgspec::Pkg.Types.PackageSpec)
    @static if VERSION >= v"1.4.0"
        var = ctx
    else
        var = ctx.env
    end
    project_resolve!(var, [pkgspec])
    project_deps_resolve!(var, [pkgspec])
    manifest_resolve!(var, [pkgspec])
    try
        ensure_resolved(var, [pkgspec])
    catch
        return false
    end
    return true
end

