
# Originally from Pkg.Operations.sandbox

"""
    TestEnv.activate([pkg]; allow_reresolve=true)

Activate the test enviroment of `pkg` (defaults to current enviroment).
"""
function activate(pkg::AbstractString=current_pkg_name(); allow_reresolve=true)
    ctx, pkgspec = ctx_and_pkgspec(pkg)
    # This needs to be first as `gen_target_project` fixes `pkgspec.path` if it is nothing
    sandbox_project_override = maybe_gen_project_override!(ctx, pkgspec)

    source_path = pkgspec.path::String
    sandbox_path = joinpath(source_path, "test")
    sandbox_project = projectfile_path(sandbox_path)
    sandbox_preferences = nothing
    if isfile(sandbox_project)
        with_load_path([sandbox_path, Base.LOAD_PATH...]) do
            sandbox_preferences = Base.get_preferences()
        end
    else
        with_load_path([something(projectfile_path(source_path)), Base.LOAD_PATH...]) do
            sandbox_preferences = Base.get_preferences()
        end
    end

    tmp = mktempdir()
    tmp_project = projectfile_path(tmp)
    tmp_manifest = manifestfile_path(tmp)
    tmp_preferences = joinpath(tmp, first(Base.preferences_names))

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
    working_manifest = abspath!(ctx.env, sandbox_preserve(ctx.env, pkgspec, tmp_project))

    # - copy over fixed subgraphs from test subgraph
    # really only need to copy over "special" nodes
    sandbox_env = Types.EnvCache(projectfile_path(sandbox_path))
    sandbox_manifest = abspath!(sandbox_env, sandbox_env.manifest)
    for (name, uuid) in sandbox_env.project.deps
        entry = get(sandbox_manifest, uuid, nothing)
        if entry !== nothing && isfixed(entry)
            subgraph = Pkg.Operations.prune_manifest(sandbox_manifest, [uuid])
            for (uuid, entry) in subgraph
                if haskey(working_manifest, uuid)
                    Pkg.Operations.pkgerror("can not merge projects")
                end
                working_manifest[uuid] = entry
            end
        end
    end

    Types.write_manifest(working_manifest, tmp_manifest)
    # Copy over preferences
    if sandbox_preferences !== nothing
        open(tmp_preferences, "w") do io
            # TODO: should we separately import TOML?
            Pkg.TOML.print(io, sandbox_preferences::Dict{String, Any})
        end
    end

    Base.ACTIVE_PROJECT[] = tmp_project

    temp_ctx = Context()
    temp_ctx.env.project.deps[pkgspec.name] = pkgspec.uuid

    try
        Pkg.resolve(temp_ctx; io=devnull)
        @debug "Using _parent_ dep graph"
    catch err# TODO
        allow_reresolve || rethrow()
        @debug err
        @warn "Could not use exact versions of packages in manifest, re-resolving"
        temp_ctx.env.manifest.deps = Dict(
            uuid => entry for
            (uuid, entry) in temp_ctx.env.manifest.deps if isfixed(entry)
        )
        Pkg.resolve(temp_ctx; io=devnull)
        @debug "Using _clean_ dep graph"
    end

    # Now that we have set up the sandbox environment, precompile all its packages:
    # (Reconnect the `io` back to the original context so the caller can see the
    # precompilation progress.)
    Pkg._auto_precompile(temp_ctx; already_instantiated=true)

    write_env(temp_ctx.env; update_undo=false)

    return Base.active_project()
end

with_load_path(f::Function, new_load_path::String) = with_load_path(f, [new_load_path])
function with_load_path(f::Function, new_load_path::Vector{String})
    old_load_path = copy(Base.LOAD_PATH)
    copy!(Base.LOAD_PATH, new_load_path)
    try
        f()
    finally
        copy!(LOAD_PATH, old_load_path)
    end
end
