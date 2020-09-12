"Exit code for runner when unit tests fail"
const TESTS_FAILED = 3

function gen_runner_code(testfilename, logfilename, testreportsdir, test_args)
    """
    $(Base.load_path_setup_code(false))

    pushfirst!(Base.LOAD_PATH, $(repr(testreportsdir)))

    using Test
    using TestReports

    append!(empty!(ARGS), $(repr(test_args.exec)))

    ts = @testset ReportingTestSet "" begin
        include($(repr(testfilename)))
    end

    write($(repr(logfilename)), report(ts))
    any_problems(ts) && exit(TestReports.TESTS_FAILED)
    """
end

##
using Pkg
import Pkg: PackageSpec, Types
import Pkg.Types: Context, EnvCache, ensure_resolved, is_project_uuid
import Pkg.Operations: project_resolve!, project_deps_resolve!, manifest_resolve!, manifest_info, project_rel_path

@static if VERSION >= v"1.4.0"
    import Pkg.Operations: gen_target_project
else
    import Pkg.Operations: with_dependencies_loadable_at_toplevel
end
@static if VERSION >= v"1.2.0"
    import Pkg.Operations: update_package_test!, source_path, sandbox  # not available in V1.0.5
else
    import Pkg.Operations: find_installed
    import Pkg.Types: SHA1
end

"""
    checkinstalled!(ctx::Union{Context, EnvCache}, pkgspec::Types.PackageSpec)

Checks if the package is installed by using `ensure_resolved` from `Pkg/src/Types.jl`.
This function fails if the package is not installed, but here we wrap it in a
try-catch as we may want to test another package after the one that isn't installed.

For Julia versions V1.4 and later, the first arguments of the Pkg functions used
is of type `Pkg.Types.Context`. For earlier versions, they are of type
`Pkg.Types.EnvCache`.
"""
function checkinstalled!(ctx::Union{Context, EnvCache}, pkgspec::Types.PackageSpec)
    project_resolve!(ctx, [pkgspec])
    project_deps_resolve!(ctx, [pkgspec])
    manifest_resolve!(ctx, [pkgspec])
    try
        ensure_resolved(ctx, [pkgspec])
    catch
        return false
    end
    return true
end

"""
    gettestfilepath(ctx::Context, pkgspec::Types.PackageSpec)

Gets the testfile path of the package. Code for each Julia version mirrors that found 
in `Pkg\\src\\Operations.jl`.
"""
function gettestfilepath(ctx::Context, pkgspec::Types.PackageSpec)
    @static if VERSION >= v"1.4.0"
        if is_project_uuid(ctx, pkgspec.uuid)
            pkgspec.path = dirname(ctx.env.project_file)
            pkgspec.version = ctx.env.pkg.version
        else
            update_package_test!(pkgspec, manifest_info(ctx, pkgspec.uuid))
            pkgspec.path = project_rel_path(ctx, source_path(ctx, pkgspec))
        end
        testfilepath = joinpath(source_path(ctx, pkgspec), "test", "runtests.jl")
    elseif VERSION >= v"1.2.0"
        pkgspec.special_action = Pkg.Types.PKGSPEC_TESTED
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.path = dirname(ctx.env.project_file)
            pkgspec.version = ctx.env.pkg.version
        else
            update_package_test!(pkgspec, manifest_info(ctx.env, pkgspec.uuid))
            pkgspec.path = joinpath(project_rel_path(ctx, source_path(pkgspec)))
        end
        testfilepath = joinpath(project_rel_path(ctx, source_path(pkgspec)), "test", "runtests.jl")
    elseif VERSION >= v"1.1.0"
        pkgspec.special_action = Pkg.Types.PKGSPEC_TESTED
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.version = ctx.env.pkg.version
            version_path = dirname(ctx.env.project_file)
        else
            entry = manifest_info(ctx.env, pkg.uuid)
            if entry.repo.tree_sha !== nothing
                version_path = find_installed(pkgspec.name, pkgspec.uuid, entry.repo.tree_sha)
            elseif entry.path !== nothing
                version_path =  project_rel_path(ctx, entry.path)
            elseif pkgspec.uuid in keys(ctx.stdlibs)
                version_path = Types.stdlib_path(pkgspec.name)
            else
                throw(PkgTestError("Could not find either `git-tree-sha1` or `path` for package $(pkgspec.name)"))
            end
        end
        testfilepath = joinpath(version_path, "test", "runtests.jl")
    else
        pkgspec.special_action = Pkg.Types.PKGSPEC_TESTED
        if is_project_uuid(ctx.env, pkgspec.uuid)
            pkgspec.version = ctx.env.pkg.version
            version_path = dirname(ctx.env.project_file)
        else        
            info = manifest_info(ctx.env, pkgspec.uuid)
            if haskey(info, "git-tree-sha1")
                version_path = find_installed(pkgspec.name, pkgspec.uuid, SHA1(info["git-tree-sha1"]))
            elseif haskey(info, "path")
                version_path =  project_rel_path(ctx, info["path"])
            elseif pkgspec.uuid in keys(ctx.stdlibs)
                version_path = Types.stdlib_path(pkgspec.name)
            else
                throw(PkgTestError("Could not find either `git-tree-sha1` or `path` for package $(pkgspec.name)"))
            end
        end
        testfilepath = joinpath(version_path, "test", "runtests.jl")
    end
    return testfilepath
end

"""
    TestReports.test(; kwargs...)
    TestReports.test(pkg::Union{AbstractString, Vector{AbstractString}; kwargs...)

**Keyword arguments:**
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
    @static if VERSION >= v"1.4.0"
       if !checkinstalled!(ctx, pkgspec)
           push!(nopkgs, pkgspec.name)
           return
       end
    else
       if !checkinstalled!(ctx.env, pkgspec)
           push!(nopkgs, pkgspec.name)
           return
       end
    end

    Pkg.instantiate(ctx)

    testfilepath = gettestfilepath(ctx, pkgspec)

    if !isfile(testfilepath)
        push!(notests, pkg)
    else
        testreportsdir = dirname(@__DIR__)
        runner_code = gen_runner_code(testfilepath, logfilename, testreportsdir, test_args)
        cmd = ```
            $(Base.julia_cmd())
            --code-coverage=$(coverage ? "user" : "none")
            --color=$(Base.have_color === nothing ? "auto" : Base.have_color ? "yes" : "no")
            --compiled-modules=$(Bool(Base.JLOptions().use_compiled_modules) ? "yes" : "no")
            --check-bounds=yes
            --depwarn=$(Base.JLOptions().depwarn == 2 ? "error" : "yes")
            --inline=$(Bool(Base.JLOptions().can_inline) ? "yes" : "no")
            --startup-file=$(Base.JLOptions().startupfile != 2 ? "yes" : "no")
            --track-allocation=$(("none", "user", "all")[Base.JLOptions().malloc_log + 1])
            $(julia_args)
            --eval $(runner_code)
            ```

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
                @info "Testing $pkg"
                proc = open(cmd, Base.stdout; write=true)
                wait(proc)
                if proc.exitcode == 0
                    @info "$pkg tests passed. Results saved to $logfilename."
                elseif proc.exitcode == TESTS_FAILED
                    @warn "ERROR: Test(s) failed or had an error in $pkg"
                    push!(errs, pkg)
                else
                    throw(PkgTestError("TestReports failed to generate the report.\nSee error log above."))
                end
            end
        else
            with_dependencies_loadable_at_toplevel(ctx, pkgspec; might_need_to_resolve=true) do localctx
                @info "Testing $pkg"
                Pkg.activate(localctx.env.project_file)
                proc = open(cmd, Base.stdout; write=true)
                wait(proc)
                Pkg.activate(ctx.env.project_file)
                if proc.exitcode == 0
                    @info "$pkg tests passed. Results saved to $logfilename."
                elseif proc.exitcode == TESTS_FAILED
                    @warn "ERROR: Test(s) failed or had an error in $pkg"
                    push!(errs, pkg)
                else
                    throw(PkgTestError("TestReports failed to generate the report.\nSee error log above."))
                end
            end
        end
    end
end

struct PkgTestError <: Exception
    msg::AbstractString
end

function Base.showerror(io::IO, ex::PkgTestError, bt; backtrace=true)
    printstyled(io, ex.msg, color=Base.error_color())
end

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
