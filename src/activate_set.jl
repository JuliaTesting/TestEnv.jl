
# Originally from Pkg.Operations.sandbox

"""
    TestEnv.activate([pkg])

Activate the test enviroment of `pkg` (defaults to current enviroment).
"""
function activate(pkg::AbstractString=current_pkg_name())
    mainctx, pkg = ctx_and_pkgspec(pkg)

    get_test_dir(mainctx, pkg)  # HACK: a side effect of this is to fix pkgspec

    # based on with_dependencies_loadable_at_toplevel
    # https://github.com/JuliaLang/Pkg.jl/blob/release-1.0/src/Operations.jl#L807


    # localctx is the context for the temporary environment we run the testing / building in
    localctx = deepcopy(mainctx)
    localctx.currently_running_target = true
    is_project = Types.is_project(localctx.env, pkg)


    # Only put `pkg` and its deps + test deps (recursively) in the temp project
    collect_deps!(seen, pkg) = begin
        pkg.uuid in seen && return
        push!(seen, pkg.uuid)
        info = manifest_info(localctx.env, pkg.uuid)
        info === nothing && return
        localctx.env.project["deps"][pkg.name] = string(pkg.uuid)
        for (dpkg, duuid) in get(info, "deps", [])
            collect_deps!(seen, PackageSpec(dpkg, UUID(duuid)))
        end
    end

    if is_project # testing the project itself
        # the project might have changes made to it so need to resolve
        need_to_resolve = true
        # Since we will create a temp environment in another place we need to extract the project
        # and put it in the Project as a normal `deps` entry and in the Manifest with a path.
        foreach(k->delete!(localctx.env.project, k), ("name", "uuid", "version"))
        localctx.env.pkg = nothing
        localctx.env.project["deps"][pkg.name] = string(pkg.uuid)
        localctx.env.manifest[pkg.name] = [Dict(
            "deps" => get_deps(mainctx, "test"),
            "uuid" => string(pkg.uuid),
            "path" => dirname(localctx.env.project_file),
            "version" => string(pkg.version)
        )]
    else
        # Only put `pkg` and its deps (recursively) in the temp project
        empty!(localctx.env.project["deps"])
        localctx.env.project["deps"][pkg.name] = string(pkg.uuid)
    end
    seen_uuids = Set{UUID}()
    collect_deps!(seen_uuids, pkg)

    pkgs = PackageSpec[]
    collect_target_deps!(localctx, pkgs, pkg, "test")
    seen_uuids = Set{UUID}()
    for dpkg in pkgs
        # Also put eventual deps of test deps in new manifest
        collect_deps!(seen_uuids, dpkg)
    end

    tmpdir = mktempdir()
    localctx.env.project_file = joinpath(tmpdir, "Project.toml")
    localctx.env.manifest_file = joinpath(tmpdir, "Manifest.toml")

    function rewrite_manifests(manifest)
        # Rewrite paths in Manifest since relative paths won't work here due to the temporary environment
        for (name, infos) in manifest
            for iinfo in infos
                # Is stdlib
                if UUID(iinfo["uuid"]) in keys(localctx.stdlibs)
                    iinfo["path"] = Types.stdlib_path(name)
                end
                if haskey(iinfo, "path")
                    iinfo["path"] = project_rel_path(mainctx, iinfo["path"])
                end
            end
        end
    end

    rewrite_manifests(localctx.env.manifest)

    # Add target deps to deps (https://github.com/JuliaLang/Pkg.jl/issues/427)
    if !isempty(pkgs)
        target_deps = deepcopy(pkgs)
        add_or_develop(localctx, pkgs)
        need_to_resolve = false # add resolves
        info = manifest_info(localctx.env, pkg.uuid)
        !haskey(info, "deps") && (info["deps"] = Dict{String, Any}())
        deps = info["deps"]
        for deppkg in target_deps
            deps[deppkg.name] = string(deppkg.uuid)
        end
    end

    # Might have added stdlibs in `add` above
    rewrite_manifests(localctx.env.manifest)

    local new
    if need_to_resolve
        resolve_versions!(localctx, pkgs)
        new = apply_versions(localctx, pkgs)
    else
        prune_manifest(localctx.env)
    end
    write_env(localctx, display_diff = false)
    need_to_resolve && build_versions(localctx, new)

    # update enviroment variables
    path_sep = Sys.iswindows() ? ';' : ':'
    ENV["JULIA_LOAD_PATH"] = "@$(path_sep)$(tmpdir)"
    delete!(ENV, "JULIA_PROJECT")
    
    return Pkg.activate(localctx.env.project_file)
end