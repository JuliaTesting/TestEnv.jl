function runner_code(testfilename, logfilename)
    """
    using Test
    using TestReports
    ts = @testset ReportingTestSet "" begin
        include("$testfilename")
    end
    open("$(logfilename)","w") do fh
        print(fh, report(ts))
    end
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
import Pkg: PackageSpec
import Pkg.Types: Context, ensure_resolved, is_project_uuid
import Pkg.Operations: project_resolve!, project_deps_resolve!, manifest_resolve!, update_package_test!, manifest_info, source_path

test(pkgs::AbstractString...; kwargs...) = test(AbstractString[i for i in pkgs]; kwargs...)

function test!(pkg::AbstractString,
               errs::Vector{AbstractString},
               nopkgs::Vector{AbstractString},
               notests::Vector{AbstractString};
               coverage::Bool=false,
               logfilepath=pwd())

   # Copied from Pkg.test approach. Needs tidying up.
   pkgspec = deepcopy(PackageSpec(pkg))
   ctx = Context()
   project_resolve!(ctx, [pkgspec])
   project_deps_resolve!(ctx, [pkgspec])
   manifest_resolve!(ctx, [pkgspec])
   try
       ensure_resolved(ctx, [pkgspec])
   catch
       push!(nopkgs, pkgspec.name)
       return
   end

   if is_project_uuid(ctx, pkgspec.uuid)
       pkgspec.path = dirname(ctx.env.project_file)
       pkgspec.version = ctx.env.pkgspec.version
   else
       update_package_test!(pkgspec, manifest_info(ctx, pkgspec.uuid))
   end
   testfilepath = joinpath(source_path(ctx, pkgspec), "test", "runtests.jl")

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
                @info "$pkg tests passed"
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
