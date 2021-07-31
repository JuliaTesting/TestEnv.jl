

if VERSION <= v"1.1"  # 1.0 or 1.1
    _sandbox(f, ctx, pkgspec) = _manual_sandbox(f, ctx, pkgspec)
elseif VERSION <= v"1.3" # 1.2 or 1.3
    function _sandbox(f, ctx, pkgspec)
        test_dir_has_project_file(ctx, pkgspec) || return _manual_sandbox(f, ctx, pkgspec)
        return sandbox(ctx, pkgspec, pkgspec.path, joinpath(pkgspec.path, "test")) do
            flush(stdout)
            f()
        end
    end
elseif VERSION >= v"1.7-a"
    function _sandbox(f, ctx, pkgspec)
        test_project_override = if !test_dir_has_project_file(ctx, pkgspec)
            gen_target_project(ctx.env, ctx.registries, pkgspec, pkgspec.path, "test")
        else
            nothing
        end
        return sandbox(ctx, pkgspec, pkgspec.path, joinpath(pkgspec.path, "test"), test_project_override) do
            flush(stdout)
            f()
        end
    end
else
    @assert VERSION >= v"1.3"
    function _sandbox(f, ctx, pkgspec)
        test_project_override = if !test_dir_has_project_file(ctx, pkgspec)
            gen_target_project(ctx, pkgspec, pkgspec.path, "test")
        else
            nothing
        end
        return sandbox(ctx, pkgspec, pkgspec.path, joinpath(pkgspec.path, "test"), test_project_override) do
            flush(stdout)
            f()
        end
    end
end
#sandbox(ctx::Context, target::PackageSpec, target_path::String,sandbox_path::String, sandbox_project_override)

function _manual_sandbox(f, ctx, pkgspec)
    with_dependencies_loadable_at_toplevel(ctx, pkgspec; might_need_to_resolve=true) do localctx
        Pkg.activate(localctx.env.project_file)
        try
            f()
        finally
            Pkg.activate(ctx.env.project_file)
        end
    end
end