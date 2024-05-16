"""
    TestEnv.activate(f, [pkg]; allow_reresolve=true)

Activate the test enviroment of `pkg` (defaults to current enviroment), and run `f()`,
then deactivate the enviroment.
This is not useful for many people: Julia is not really designed to have the enviroment
being changed while you are executing code.
However, this *is* useful for anyone doing something like making a alternative to
`Pkg.test()`.
Indeed this is basically extracted from what `Pkg.test()` does.
"""
function activate(f, pkg::AbstractString=current_pkg_name(); allow_reresolve=true)
    ctx, pkgspec = ctx_and_pkgspec(pkg)

    test_project_override = maybe_gen_project_override!(ctx, pkgspec)
    path = pkgspec.path::String
    @static if VERSION < v"1.11-"
        return sandbox(ctx, pkgspec, path, joinpath(path, "test"), test_project_override; allow_reresolve) do
            flush(stdout)
            f()
        end
    else
        return sandbox(ctx, pkgspec, joinpath(path, "test"), test_project_override; allow_reresolve) do
            flush(stdout)
            f()
        end
    end
end
