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

test(pkgs::AbstractString...; kwargs...) = test(AbstractString[i for i in pkgs]; kwargs...)

function test!(pkg::AbstractString,
               errs::Vector{AbstractString},
               nopkgs::Vector{AbstractString},
               notests::Vector{AbstractString};
               coverage::Bool=false,
               logfilepath=pwd())

    reqs_path = abspath(pkg,"test","REQUIRE")
    if isfile(reqs_path)
        tests_require = Reqs.parse(reqs_path)
        if (!isempty(tests_require))
            @info "Computing test dependencies for $pkg..."
            resolve(merge(Reqs.parse("REQUIRE"), tests_require))
        end
    end
    test_path = abspath(pkg,"test","runtests.jl")
    if !isdir(pkg)
        push!(nopkgs, pkg)
    elseif !isfile(test_path)
        push!(notests, pkg)
    else
        @info "Testing $pkg"
        logfilename = joinpath(logfilepath, "testlog.xml") # TODO handle having multiple packages called on after the other
        runner_file_path = make_runner_file(test_path, logfilename)
        cd(dirname(test_path)) do
            try
                cmd = ```
                    $(Base.julia_cmd())
                    --code-coverage=$(coverage ? "user" : "none")
                    --color=$(Base.have_color ? "yes" : "no")
                    --compilecache=$(Bool(Base.JLOptions().use_compilecache) ? "yes" : "no")
                    --check-bounds=yes
                    --startup-file=$(Base.JLOptions().startupfile != 2 ? "yes" : "no")
                    $(runner_file_path)
                    ```
                run(cmd)
                @info "$pkg tests passed"
            catch err
                Base.Pkg.Entry.warnbanner(err, label="[ ERROR: \$pkg ]")
                push!(errs,pkg)
            end
        end
    end
    isfile(reqs_path) && resolve()
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
        throw(PkgTestError(join(messages, "and")))
    end
end

test(;coverage::Bool=false, logfilepath=pwd()) = test(sort!(AbstractString[keys(installed())...]); coverage=coverage, logfilepath=logfilepath)
