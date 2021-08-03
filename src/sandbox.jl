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
