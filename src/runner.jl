""""
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

"""
    gettestdir(ctx::Context, pkgspec::Pkg.Types.PackageSpec)

Gets the testfile path of the package. Code for each Julia version mirrors that found 
in `Pkg/src/Operations.jl`.
"""
function gettestdir(ctx::Context, pkgspec::Pkg.Types.PackageSpec)
    @static if VERSION >= v"1.4.0"
        if is_project_uuid(ctx, pkgspec.uuid)
            pkgspec.path = dirname(ctx.env.project_file)
            pkgspec.version = ctx.env.pkg.version
        else
            update_package_test!(pkgspec, manifest_info(ctx, pkgspec.uuid))
            pkgspec.path = project_rel_path(ctx, source_path(ctx, pkgspec))
        end
        pkgfilepath = source_path(ctx, pkgspec)
    elseif VERSION >= v"1.2.0"
        pkgspec.special_action = Pkg.Types.PKGSPEC_TESTED
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.path = dirname(ctx.env.project_file)
            pkgspec.version = ctx.env.pkg.version
        else
            update_package_test!(pkgspec, manifest_info(ctx.env, pkgspec.uuid))
            pkgspec.path = joinpath(project_rel_path(ctx, source_path(pkgspec)))
        end
        pkgfilepath = project_rel_path(ctx, source_path(pkgspec))
    elseif VERSION >= v"1.1.0"
        pkgspec.special_action = Pkg.Types.PKGSPEC_TESTED
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.version = ctx.env.pkg.version
            pkgfilepath = dirname(ctx.env.project_file)
        else
            entry = manifest_info(ctx.env, pkg.uuid)
            if entry.repo.tree_sha !== nothing
                pkgfilepath = find_installed(pkgspec.name, pkgspec.uuid, entry.repo.tree_sha)
            elseif entry.path !== nothing
                pkgfilepath =  project_rel_path(ctx, entry.path)
            elseif pkgspec.uuid in keys(ctx.stdlibs)
                pkgfilepath = Pkg.Types.stdlib_path(pkgspec.name)
            else
                throw(PkgTestError("Could not find either `git-tree-sha1` or `path` for package $(pkgspec.name)"))
            end
        end
    else
        pkgspec.special_action = Pkg.Types.PKGSPEC_TESTED
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.version = ctx.env.pkg.version
            pkgfilepath = dirname(ctx.env.project_file)
        else        
            info = manifest_info(ctx.env, pkgspec.uuid)
            if haskey(info, "git-tree-sha1")
                pkgfilepath = find_installed(pkgspec.name, pkgspec.uuid, SHA1(info["git-tree-sha1"]))
            elseif haskey(info, "path")
                pkgfilepath =  project_rel_path(ctx, info["path"])
            elseif pkgspec.uuid in keys(ctx.stdlibs)
                pkgfilepath = Pkg.Types.stdlib_path(pkgspec.name)
            else
                throw(PkgTestError("Could not find either `git-tree-sha1` or `path` for package $(pkgspec.name)"))
            end
        end
    end
    return joinpath(pkgfilepath, "test")
end


current_pkg_name() = Context().env.pkg.name

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
function activate(f, pkg=current_pkg_name())
    pkgspec = deepcopy(PackageSpec(pkg))
    ctx = Context()
    isinstalled!(ctx, pkgspec) || error("$pkg not installed 👻")

    Pkg.instantiate(ctx)
    testdir = gettestdir(ctx, pkgspec)
    test_folder_has_project_file = isfile(joinpath(testdir, "Project.toml"))

    if VERSION >= v"1.4.0" || (VERSION >= v"1.2.0" && test_folder_has_project_file)
        # Operations.sandbox() has different arguments between versions
        sandbox_args = (ctx,
                        pkgspec,
                        pkgspec.path,
                        joinpath(pkgspec.path, "test"))
        if VERSION >= v"1.4.0"
            test_project_override = test_folder_has_project_file ?
                nothing :
                gen_target_project(ctx, pkgspec, pkgspec.path, "test")
            sandbox_args = (sandbox_args..., test_project_override)
        end

        sandbox(sandbox_args...) do
            flush(stdout)
            f()
        end
    else
        with_dependencies_loadable_at_toplevel(ctx, pkgspec; might_need_to_resolve=true) do localctx
            Pkg.activate(localctx.env.project_file)
            try
                f()
            finally
                Pkg.activate(ctx.env.project_file)
            end
        end
    end
end
