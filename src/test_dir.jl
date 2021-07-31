[function test_dir_has_project_file(ctx, pkgspec)
    return isfile(joinpath(get_test_dir(ctx, pkgspec), "Project.toml"))
end

"""
    get_test_dir(ctx::Context, pkgspec::Pkg.Types.PackageSpec)

Gets the testfile path of the package. Code for each Julia version mirrors that found 
in `Pkg/src/Operations.jl`.
"""
function get_test_dir(ctx::Context, pkgspec::Pkg.Types.PackageSpec)
    @static if VERSION >= v"1.7.0-a"
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.path = dirname(ctx.env.project_file)
            pkgspec.version = ctx.env.pkg.version
        else
            update_package_test!(pkgspec, manifest_info(ctx.env.manifest, pkgspec.uuid))
            pkgspec.path = project_rel_path(ctx.env, source_path(ctx.env.project_file, pkgspec))
        end
        pkgfilepath = source_path(ctx.env.project_file, pkgspec)
    elseif VERSION >= v"1.4.0"
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
                throw(TestEnvError("Could not find either `git-tree-sha1` or `path` for package $(pkgspec.name)"))
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
                throw(TestEnvError("Could not find either `git-tree-sha1` or `path` for package $(pkgspec.name)"))
            end
        end
    end
    return joinpath(pkgfilepath, "test")
end
]