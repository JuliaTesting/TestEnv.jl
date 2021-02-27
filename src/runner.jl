"Exit code for runner when tests fail"
const TESTS_FAILED = 3

"""
    get_deps(manifest, pkg) = get_deps!(String[], manifest, pkg)

Get list of dependencies for `pkg` found in `manifest`
"""
get_deps(manifest, pkg) = get_deps!(String[], manifest, pkg)

"""
    get_deps!(deps, manifest, pkg)

Push dependencies for `pkg` found in `manifest` into `deps`.
"""
function get_deps!(deps, manifest, pkg)
    if haskey(manifest[pkg][1], "deps")
        for dep in manifest[pkg][1]["deps"]
            if !(dep in deps)
                push!(deps, dep)
                get_deps!(deps, manifest, dep)
            end
        end
    end
    return unique(deps)
end

"""
    get_manifest()

Return the parsed manifest that has `TestReports` as a dependency.
"""
function get_manifest()
    # Check all environments in LOAD_PATH to see if `TestReports` is
    # in the manifest
    for path in Base.load_path()
        manifest_path = replace(path, "Project.toml"=>"Manifest.toml")
        if isfile(manifest_path)
            manifest = Pkg.TOML.parsefile(manifest_path)
            haskey(manifest, "TestReports") && return manifest
        end
    end

    # Should be impossible to get here, but let's error just in case.
    throw(PkgTestError("No environment has TestReports as a dependency and TestReports is not the active project."))
    return
end

"""
    make_testreports_environment(manifest)

Make a new environment in a temporary directory, using information
from the parsed `manifest` provided.
"""
function make_testreports_environment(manifest)
    all_deps = get_deps(manifest, "TestReports")
    push!(all_deps, "TestReports")
    new_manifest = Dict(pkg => manifest[pkg] for pkg in all_deps)

    new_project = Dict(
        "deps" => Dict(
            "Test" => new_manifest["Test"][1]["uuid"],
            "TestReports" => new_manifest["TestReports"][1]["uuid"]
        )
    )
    testreportsenv = mktempdir()
    open(joinpath(testreportsenv, "Project.toml"), "w") do io
        Pkg.TOML.print(io, new_project)
    end
    open(joinpath(testreportsenv, "Manifest.toml"), "w") do io
        Pkg.TOML.print(io, new_manifest, sorted=true)
    end
    return testreportsenv
end

"""
    get_testreports_environment()

Returns new environment to be pushed to `LOAD_PATH` to ensure `TestReports`,
`Test` and their dependencies are available for report generation.
"""
function get_testreports_environment()
    manifest = get_manifest()    
    return make_testreports_environment(manifest)
end

"""
    gen_runner_code(testfilename, logfilename, test_args)

Returns runner code that will run the tests and generate the report in a new
Julia instance.
"""
function gen_runner_code(testfilename, logfilename, test_args)
    if Base.active_project() == joinpath(dirname(@__DIR__), "Project.toml")
        # TestReports is the active project, so push first so correct version is used
        load_path_text = "pushfirst!(Base.LOAD_PATH, $(repr(dirname(@__DIR__))))"
    else
        # TestReports is a dependency of one of the environments, find and build temporary environment
        testreportsenv = get_testreports_environment()
        load_path_text = "push!(Base.LOAD_PATH, $(repr(testreportsenv)))"
    end

    runner_code = """
        $(Base.load_path_setup_code(false))

        $load_path_text

        using Test
        using TestReports

        append!(empty!(ARGS), $(repr(test_args.exec)))

        ts = @testset ReportingTestSet "" begin
            include($(repr(testfilename)))
        end

        write($(repr(logfilename)), report(ts))
        any_problems(ts) && exit(TestReports.TESTS_FAILED)
        """
    return runner_code
end

"""
    gen_command(runner_code, julia_args, coverage)

Returns `Cmd` which will run the runner code in a new Julia instance.

See also: [`gen_runner_code`](@ref)
"""
function gen_command(runner_code, julia_args, coverage)
    @static if VERSION >= v"1.5.0"
        threads_cmd = `--threads=$(Threads.nthreads())`
    else
        threads_cmd = ``
    end

    cmd = ```
        $(Base.julia_cmd())
        --code-coverage=$(coverage ? "user" : "none")
        --color=$(Base.have_color === nothing ? "auto" : Base.have_color ? "yes" : "no")
        --compiled-modules=$(Bool(Base.JLOptions().use_compiled_modules) ? "yes" : "no")
        --check-bounds=yes
        --depwarn=$(Base.JLOptions().depwarn == 2 ? "error" : "yes")
        --inline=$(Bool(Base.JLOptions().can_inline) ? "yes" : "no")
        --startup-file=$(Base.JLOptions().startupfile == 1 ? "yes" : "no")
        --track-allocation=$(("none", "user", "all")[Base.JLOptions().malloc_log + 1])
        $threads_cmd
        $(julia_args)
        --eval $(runner_code)
        ```
    return cmd
end

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

"""
    gettestfilepath(ctx::Context, pkgspec::Pkg.Types.PackageSpec)

Gets the testfile path of the package. Code for each Julia version mirrors that found 
in `Pkg/src/Operations.jl`.
"""
function gettestfilepath(ctx::Context, pkgspec::Pkg.Types.PackageSpec)
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
    testfilepath = joinpath(pkgfilepath, "test", "runtests.jl")
    return testfilepath
end

"""
    checkexitcode!(errs, proc, pkg, logfilename)

Checks `proc.exitcode` and acts as follows:

 - If 0, displays tests passed info message
 - If equal to `TESTS_FAILED` const, warning is displayed and `pkg` added to `errs`
 - If anything else, throws a `PkgTestError`
"""
function checkexitcode!(errs, proc, pkg, logfilename)
    if proc.exitcode == 0
        @info "$pkg tests passed. Results saved to $logfilename."
    elseif proc.exitcode == TESTS_FAILED
        @warn "ERROR: Test(s) failed or had an error in $pkg"
        push!(errs, pkg)
    else
        throw(PkgTestError("TestReports failed to generate the report.\nSee error log above."))
    end
end

"""
    runtests!(errs::Vector, pkg, cmd, logfilename)

Runs `cmd` which will run the tests of `pkg`. The exit code of the process
is then checked.
"""
function runtests!(errs::Vector, pkg, cmd, logfilename)
    @info "Testing $pkg"
    proc = open(cmd, Base.stdout; write=true)
    wait(proc)
    checkexitcode!(errs, proc, pkg, logfilename)
end

"""
    test!(pkg::AbstractString,
          errs::Vector{AbstractString},
          nopkgs::Vector{AbstractString},
          notests::Vector{AbstractString},
          logfilename::AbstractString;
          coverage::Bool=false,
          julia_args::Union{Cmd, AbstractVector{<:AbstractString}}=``,
          test_args::Union{Cmd, AbstractVector{<:AbstractString}}=``)

Tests `pkg` and save report to `logfilename`. Tests are run in the same way
as `Pkg.test`.

If tests error `pkg` is added to `nopkgs`. If `pkg` has no testfile it is added to
`notests`. If `pkg` is not installed it is added to `nopkgs`.
"""
function test!(pkg::AbstractString,
               errs::Vector{AbstractString},
               nopkgs::Vector{AbstractString},
               notests::Vector{AbstractString},
               logfilename::AbstractString;
               coverage::Bool=false,
               julia_args::Union{Cmd, AbstractVector{<:AbstractString}}=``,
               test_args::Union{Cmd, AbstractVector{<:AbstractString}}=``)

    # Copied from Pkg.test approach
    julia_args = Cmd(julia_args)
    test_args = Cmd(test_args)
    pkgspec = deepcopy(PackageSpec(pkg))
    ctx = Context()
    
    if !isinstalled!(ctx, pkgspec)
        push!(nopkgs, pkgspec.name)
        return
    end
    Pkg.instantiate(ctx)
    testfilepath = gettestfilepath(ctx, pkgspec)

    if !isfile(testfilepath)
        push!(notests, pkg)
    else
        runner_code = gen_runner_code(testfilepath, logfilename, test_args)
        cmd = gen_command(runner_code, julia_args, coverage)
        test_folder_has_project_file = isfile(joinpath(dirname(testfilepath), "Project.toml"))

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
                runtests!(errs, pkg, cmd, logfilename)
            end
        else
            with_dependencies_loadable_at_toplevel(ctx, pkgspec; might_need_to_resolve=true) do localctx
                Pkg.activate(localctx.env.project_file)
                try
                    runtests!(errs, pkg, cmd, logfilename)
                finally
                    Pkg.activate(ctx.env.project_file)
                end
            end
        end
    end
end

"""
    TestReports.test(; kwargs...)
    TestReports.test(pkg::Union{AbstractString, Vector{AbstractString}; kwargs...)

# Keyword arguments:
  - `coverage::Bool=false`: enable or disable generation of coverage statistics.
  - `julia_args::Union{Cmd, Vector{String}}`: options to be passed to the test process.
  - `test_args::Union{Cmd, Vector{String}}`: test arguments (`ARGS`) available in the test process.
  - `logfilepath::AbstractString=pwd()`: file path where test reports are saved.
  - `logfilename::Union{AbstractString, Vector{AbstractString}}`: name(s) of test report file(s).

Generates a JUnit XML for the tests of package `pkg`, or for the current project
(which thus needs to be a package) if no positional argument is given to
`TestReports.test`. The test report is saved in the current working directory and
called `testlog.xml` if both `logfilepath` and `logfilename` are not supplied.
If `pkg` is of type `Vector{String}`, the report filenames are prepended with the
package name, for example `Example_testlog.xml`.

If `logfilename` is supplied, it must match the type (and length, if a vector) of `pkg`.

The tests are run in the same way as `Pkg.test`.
"""
function test(; kwargs...)
    ctx = Context()
    # This error mirrors the message generated by Pkg.test in similar situations
    ctx.env.pkg === nothing && throw(PkgTestError("trying to test an unnamed project"))
    test(ctx.env.pkg.name; kwargs...)
end
test(pkg::AbstractString; logfilename::AbstractString="testlog.xml", kwargs...) = test([pkg]; logfilename=[logfilename], kwargs...)
function test(pkgs::Vector{<:AbstractString}; 
              logfilename::Vector{<:AbstractString}=[pkg * "_testlog.xml" for pkg in pkgs], 
              logfilepath::AbstractString=pwd(), 
              kwargs...)
              
    # Argument check
    err_str = "The number of file names supplied must equal the number of packages being tested"
    length(pkgs) != length(logfilename) && throw(ArgumentError(err_str))

    # Make logfilepath directory if it doesn't exist
    !isdir(logfilepath) && mkdir(logfilepath)

    errs = AbstractString[]
    nopkgs = AbstractString[]
    notests = AbstractString[]
    for (pkg, filename) in zip(pkgs, logfilename)
        test!(pkg, errs, nopkgs, notests, joinpath(logfilepath, filename); kwargs...)
    end
    if !all(isempty, (errs, nopkgs, notests))
        messages = AbstractString[]
        if !isempty(errs)
            push!(messages, "$(join(errs,", "," and ")) had test errors")
        end
        if !isempty(nopkgs)
            msg = length(nopkgs) > 1 ? " are not installed packages" :
                                       " is not an installed package"
            push!(messages, string(join(nopkgs,", ", " and "), msg))
        end
        if !isempty(notests)
            push!(messages, "$(join(notests,", "," and ")) did not provide a test/runtests.jl file")
        end
        throw(PkgTestError(join(messages, " and ")))
    end
end

struct PkgTestError <: Exception
    msg::AbstractString
end

function Base.showerror(io::IO, ex::PkgTestError, bt; backtrace=true)
    printstyled(io, ex.msg, color=Base.error_color())
end
