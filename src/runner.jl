function runner_code(testfilename, logfilename)
    """
    using Test
    using TestReports

    ts = @testset ReportingTestSet "" begin
        include($(repr(testfilename)))
    end

    write($(repr(logfilename)), report(ts))
    exit(any_problems(ts))
    """
end

function make_runner_file(testfilename, logfilename)
    fn, fh = mktemp()
    atexit(()->rm(fn, force=true))
    println(fh, runner_code(testfilename, logfilename))
    close(fh)
    fn
end

##
import Pkg: PackageSpec, Types
import Pkg.Types: Context, EnvCache, ensure_resolved, is_project_uuid
import Pkg.Operations: project_resolve!, project_deps_resolve!, manifest_resolve!, manifest_info, project_rel_path

@static if VERSION >= v"1.2.0"
    import Pkg.Operations: update_package_test!, source_path  # not available in V1.0
else
    import Pkg.Operations: find_installed
    import Pkg.Types: SHA1
end

"""
    checkinstalled!(ctx::Union{Context, EnvCache}, pkgspec::Types.PackageSpec)

Checks if the package is installed.

For Julia versions V1.3 and later, the first arguments of the Pkg functions used
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
    gettestfilepath_pre_v1_2(ctx::Context, pkgspec::Types.PackageSpec)

Gets the test file path for Julia versions before v1.2.0. Needs to be different
due to differences within Pkg.
"""
function gettestfilepath_pre_v1_2(ctx::Context, pkgspec::Types.PackageSpec)
    if is_project_uuid(ctx.env, pkgspec.uuid)
        pkgspec.version = ctx.env.pkg.version
        version_path = dirname(ctx.env.project_file)
    else
        @static if VERSION >= v"1.1.0"
            entry = manifest_info(ctx.env, pkg.uuid)
            if entry.repo.tree_sha !== nothing
                version_path = find_installed(pkgspec.name, pkgspec.uuid, entry.repo.tree_sha)
            elseif entry.path !== nothing
                version_path =  project_rel_path(ctx, entry.path)
            elseif pkg.uuid in keys(ctx.stdlibs)
                version_path = Types.stdlib_path(pkgspec.name)
            else
                PkgTestError("Could not find either `git-tree-sha1` or `path` for package $(pkg.name)")
            end
        else
            info = manifest_info(ctx.env, pkgspec.uuid)
            if haskey(info, "git-tree-sha1")  # Doesn't work with 1.2, 1.3
                version_path = find_installed(pkgspec.name, pkgspec.uuid, SHA1(info["git-tree-sha1"]))
            elseif haskey(info, "path")  # Doesn't work with 1.2, 1.3
                version_path =  project_rel_path(ctx, info["path"])
            elseif pkg.uuid in keys(ctx.stdlibs)
                version_path = Types.stdlib_path(pkgspec.name)
            else
                PkgTestError("Could not find either `git-tree-sha1` or `path` for package $(pkg.name)")
            end
        end
    end
    testfilepath = joinpath(version_path, "test", "runtests.jl")
    return testfilepath
end

"""
    gettestfilepath_v1_2(ctx::Context, pkgspec::Types.PackageSpec)

Gets the test file path for Julia versions V1.2.0 and V1.3.1.
"""
function gettestfilepath_v1_2(ctx::Context, pkgspec::Types.PackageSpec)
    if is_project_uuid(ctx.env, pkgspec.uuid)
        pkgspec.path = dirname(ctx.env.project_file)
        pkgspec.version = ctx.env.pkgspec.version
    else
        update_package_test!(pkgspec, manifest_info(ctx.env, pkgspec.uuid))
    end
    testfilepath = joinpath(project_rel_path(ctx, source_path(pkgspec)), "test", "runtests.jl")
    return testfilepath
end

"""
    gettestfilepath(ctx::Context, pkgspec::Types.PackageSpec)

Gets the test file path for Julia versions V1.4.0 and later.
"""
function gettestfilepath(ctx::Context, pkgspec::Types.PackageSpec)
    if is_project_uuid(ctx, pkgspec.uuid)
        pkgspec.path = dirname(ctx.env.project_file)
        pkgspec.version = ctx.env.pkgspec.version
    else
        update_package_test!(pkgspec, manifest_info(ctx, pkgspec.uuid))
    end
    testfilepath = joinpath(source_path(ctx, pkgspec), "test", "runtests.jl")
    return testfilepath
end

test(pkgs::AbstractString...; kwargs...) = test(AbstractString[i for i in pkgs]; kwargs...)

function test!(pkg::AbstractString,
               errs::Vector{AbstractString},
               nopkgs::Vector{AbstractString},
               notests::Vector{AbstractString};
               coverage::Bool=false,
               logfilepath=pwd())

   # Copied from Pkg.test approach
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

    @static if VERSION >= v"1.4.0"
        testfilepath = gettestfilepath(ctx, pkgspec)
    elseif VERSION >= v"1.2.0"
        testfilepath = gettestfilepath_v1_2(ctx, pkgspec)
    else
        testfilepath = gettestfilepath_pre_v1_2(ctx, pkgspec)
    end

    if !isfile(testfilepath)
        push!(notests, pkg)
    else
        @info "Testing $pkg"
        logfilename = joinpath(logfilepath, "testlog.xml") # TODO handle having multiple packages called on after the other
        runner_file_path = make_runner_file(testfilepath, logfilename)
        cd(dirname(testfilepath)) do
            try
                cmd = ```
                    $(Base.julia_cmd())
                    --code-coverage=$(coverage ? "user" : "none")
                    --color=$(Base.have_color ? "yes" : "no")
                    --compiled-modules=$(Bool(Base.JLOptions().use_compiled_modules) ? "yes" : "no")
                    --check-bounds=yes
                    --depwarn=$(Base.JLOptions().depwarn == 2 ? "error" : "yes")
                    --inline=$(Bool(Base.JLOptions().can_inline) ? "yes" : "no")
                    --startup-file=$(Base.JLOptions().startupfile != 2 ? "yes" : "no")
                    --track-allocation=$(("none", "user", "all")[Base.JLOptions().malloc_log + 1])
                    $(runner_file_path)
                    ```
                run(cmd)
                @info "$pkg tests passed. Results saved to $logfilename."
            catch err
                @warn "ERROR: Test(s) failed or had an error in $pkg"
                push!(errs,pkg)
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

function test(pkgs::Vector{AbstractString}; coverage::Bool=false, logfilepath = pwd())
    errs = AbstractString[]
    nopkgs = AbstractString[]
    notests = AbstractString[]
    for pkg in pkgs
        test!(pkg,errs,nopkgs,notests; coverage=coverage, logfilepath=logfilepath)
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

test(;coverage::Bool=false, logfilepath=pwd()) = test(sort!(AbstractString[keys(installed())...]); coverage=coverage, logfilepath=logfilepath)
