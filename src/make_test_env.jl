# Originally from Pkg.Operations.sandbox
function make_test_env(ctx::Context, target)
    # This needs to be first as `gen_target_project` fixes `target.path` if it is nothing
    sandbox_project_override = if !test_dir_has_project_file(ctx, target)
        sandbox_project_override = gen_target_project(ctx, target, target.path, "test")
    else
        nothing
    end

    sandbox_path = joinpath(target.path, "test")
    sandbox_project = projectfile_path(sandbox_path)

    tmp = mktempdir()
    tmp_project = projectfile_path(tmp)
    tmp_manifest = manifestfile_path(tmp)

    # Copy env info over to temp env
    if sandbox_project_override !== nothing 
        Types.write_project(sandbox_project_override, tmp_project)
    elseif isfile(sandbox_project)
        cp(sandbox_project, tmp_project)
        chmod(tmp_project, 0o600)
    end
    # create merged manifest
    # - copy over active subgraph
    # - abspath! to maintain location of all deved nodes
    working_manifest = abspath!(ctx, sandbox_preserve(ctx, target, tmp_project))
    # - copy over fixed subgraphs from test subgraph
    # really only need to copy over "special" nodes
    sandbox_env = Types.EnvCache(projectfile_path(sandbox_path))
    sandbox_manifest = abspath!(sandbox_path, sandbox_env.manifest)
    for (name, uuid) in sandbox_env.project.deps
        entry = get(sandbox_manifest, uuid, nothing)
        if entry !== nothing && isfixed(entry)
            subgraph = prune_manifest(sandbox_manifest, [uuid])
            for (uuid, entry) in subgraph
                if haskey(working_manifest, uuid)
                    pkgerror("can not merge projects")
                end
                working_manifest[uuid] = entry
            end
        end
    end

    Types.write_manifest(working_manifest, tmp_manifest)

    # sandbox
    push!(empty!(LOAD_PATH), "@", tmp)
    Base.ACTIVE_PROJECT[] = nothing

    temp_ctx = Context()
    temp_ctx.env.project.deps[target.name] = target.uuid

    try
        Pkg.resolve(temp_ctx; io=devnull)
        @debug "Using _parent_ dep graph"
    catch err# TODO
        @debug err
        @warn "Could not use exact versions of packages in manifest, re-resolving"
        temp_ctx.env.manifest.deps = Dict(
            uuid => entry for
            (uuid, entry) in temp_ctx.env.manifest.deps if isfixed(entry)
        )
        Pkg.resolve(temp_ctx; io=devnull)
        @debug "Using _clean_ dep graph"
    end

    # Absolutify stdlibs paths
    for (uuid, entry) in temp_ctx.env.manifest
        if is_stdlib(uuid)
            entry.path = Types.stdlib_path(entry.name)
        end
    end
    write_env(temp_ctx.env; update_undo=false)

    # update enviroment variables
    path_sep = Sys.iswindows() ? ';' : ':'
    ENV["JULIA_LOAD_PATH"] = "@$(path_sep)$(tmp)"
    delete!(ENV, "JULIA_PROJECT")
    
    return Base.active_project()
end
