function test_dir_has_project_file(ctx, pkgspec)
    return isfile(joinpath(get_test_dir(ctx, pkgspec), "Project.toml"))
end

"""
    get_test_dir(ctx::Context, pkgspec::Pkg.Types.PackageSpec)

Gets the testfile path of the package. Code for each Julia version mirrors that found 
in `Pkg/src/Operations.jl`.
"""
function get_test_dir(ctx::Context, pkgspec::Pkg.Types.PackageSpec)
    if is_project_uuid(ctx, pkgspec.uuid)
        pkgspec.path = dirname(ctx.env.project_file)
        pkgspec.version = ctx.env.pkg.version
    else
        update_package_test!(pkgspec, manifest_info(ctx, pkgspec.uuid))
        pkgspec.path = project_rel_path(ctx, source_path(ctx, pkgspec))
    end
    pkgfilepath = source_path(ctx, pkgspec)
    return joinpath(pkgfilepath, "test")
end
