@testset "activate_set.jl" begin
    @testset "activate [extras]" begin
        mktempdir() do p
            Pkg.activate(p)
            Pkg.add(PackageSpec(name="ChainRulesCore", version="1.0.2"))

            orig_project_toml_path = Base.active_project()
            orig_load_path = copy(LOAD_PATH)
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            try
                TestEnv.activate("ChainRulesCore")
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path

                @eval using StaticArrays  # From ChainRulesCore [extras] Project.toml
                @test Base.invokelatest(isdefined, @__MODULE__, :StaticArrays)

                @eval using Compat  # from ChainRulesCore Project.toml
                @test Base.invokelatest(isdefined, @__MODULE__, :Compat)
            finally
                Pkg.activate(orig_project_toml_path)
                # No longer is enviroment active
                @test_throws ArgumentError @eval using OffsetArrays
                pop!(LOAD_PATH)
                @test orig_load_path == LOAD_PATH
            end
        end
    end

    @testset "activate test/Project" begin
        mktempdir() do p
            Pkg.activate(p)

            if VERSION >= v"1.4-"
                Pkg.add(PackageSpec(name="YAXArrays", version="0.1.3"))

                orig_project_toml_path = Base.active_project()
                orig_load_path = copy(LOAD_PATH)
                push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
                try
                    # YAXArrays has a test/Project.toml, which contains CSV
                    if VERSION >= v"1.8-"
                        kw = (; allow_reresolve=false)
                    else
                        kw = NamedTuple()
                    end
                    TestEnv.activate("YAXArrays"; kw...)
                    new_project_toml_path = Base.active_project()
                    @test new_project_toml_path != orig_project_toml_path

                    @eval using CSV
                    @test Base.invokelatest(isdefined, @__MODULE__, :CSV)

                finally
                    Pkg.activate(orig_project_toml_path)
                    pop!(LOAD_PATH)
                    @test orig_load_path == LOAD_PATH
                end
            elseif VERSION >= v"1.2-"
                Pkg.add(PackageSpec(name="ConstraintSolver", version="0.6.10"))

                orig_project_toml_path = Base.active_project()
                orig_load_path = copy(LOAD_PATH)
                push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
                try
                    # ConstraintSolver has a test/Project.toml, which contains CSV
                    if VERSION >= v"1.8-"
                        kw = (; allow_reresolve=false)
                    else
                        kw = NamedTuple()
                    end
                    TestEnv.activate("ConstraintSolver"; kw...)
                    new_project_toml_path = Base.active_project()
                    @test new_project_toml_path != orig_project_toml_path

                    @eval using JSON
                    @test Base.invokelatest(isdefined, @__MODULE__, :JSON)

                finally
                    Pkg.activate(orig_project_toml_path)
                    pop!(LOAD_PATH)
                    @test orig_load_path == LOAD_PATH
                end
            end
        end

        if VERSION >= v"1.4-"
            # https://github.com/JuliaTesting/TestEnv.jl/issues/26
            @test isdefined(TestEnv, :isfixed)
        end
    end

    if VERSION >= v"1.11"
        @testset "activate with [sources]" begin
            orig_project_toml_path = Base.active_project()
            orig_load_path = copy(LOAD_PATH)
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            try
                Pkg.activate(joinpath(@__DIR__, "sources", "MainEnv"))
                TestEnv.activate()
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path
                @eval using MainEnv
                @test isdefined(@__MODULE__, :MainEnv)
                @test MainEnv.bar() == 42
            finally
                Pkg.activate(orig_project_toml_path)
                pop!(LOAD_PATH)
                @test orig_load_path == LOAD_PATH
            end
        end
        @testset "activate with [sources] and two Project.toml approach" begin
            orig_project_toml_path = Base.active_project()
            orig_load_path = copy(LOAD_PATH)
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            try
                Pkg.activate(joinpath(@__DIR__, "sources", "MainTestProjectEnv"))
                TestEnv.activate()
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path
                @eval using MainTestProjectEnv
                @test isdefined(@__MODULE__, :MainTestProjectEnv)
                @test MainTestProjectEnv.bar() == 42
            finally
                Pkg.activate(orig_project_toml_path)
                pop!(LOAD_PATH)
                @test orig_load_path == LOAD_PATH
            end
        end
    end

    if VERSION >= v"1.12-"
        @testset "activate [workspace] test env" begin
            orig_project_toml_path = Base.active_project()
            orig_load_path = copy(LOAD_PATH)
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            try
                Pkg.activate(joinpath(@__DIR__, "sources", "WorkspaceTestEnv"))
                TestEnv.activate()
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path
                @eval using WorkspaceTestEnv
                @test isdefined(@__MODULE__, :WorkspaceTestEnv)
                @test WorkspaceTestEnv.foo() == 42
            finally
                Pkg.activate(orig_project_toml_path)
                pop!(LOAD_PATH)
                @test orig_load_path == LOAD_PATH
            end
        end
    end

    if VERSION >= v"1.6" # JULIA_PKG_PRECOMPILE_AUTO was introduced in 1.6
        @testset "JULIA_PKG_PRECOMPILE_AUTO compatibility" begin
            mktempdir() do p
                withenv("JULIA_PKG_PRECOMPILE_AUTO" => "0") do
                    orig_load_path = copy(LOAD_PATH)
                    push!(empty!(LOAD_PATH), p)

                    # Restrict the depot path to avoid grabbing a precompiled version from a
                    # stacked environment
                    orig_depot_path = copy(DEPOT_PATH)
                    push!(empty!(DEPOT_PATH), mkdir(joinpath(p, ".julia")))

                    try
                        Pkg.activate(p)
                        orig_project_toml_path = Base.active_project()
                        try
                            Pkg.develop(PackageSpec(path=pkgdir(TestEnv)))
                            Pkg.add(PackageSpec(name="Example"))
                            try
                                TestEnv.activate("Example")
                                if VERSION < v"1.10" # Base.isprecompiled was added in 1.10
                                    cache_dir = Base.compilecache_dir(Base.identify_package("Example"))
                                    @test !isdir(cache_dir) || isempty(readdir(cache_dir))
                                else
                                    @test !Base.isprecompiled(Base.identify_package("Example"))
                                end
                            catch e
                                @error "Error during TestEnv.activate/isprecompiled check" exception=(e, catch_backtrace())
                                @test false
                            end
                            new_project_toml_path = Base.active_project()
                            @test new_project_toml_path != orig_project_toml_path
                        finally
                            Pkg.activate(orig_project_toml_path)
                        end
                    finally
                        if isdefined(@__MODULE__, :orig_load_path)
                            pop!(LOAD_PATH)
                            append!(LOAD_PATH, orig_load_path)
                        end
                        if isdefined(@__MODULE__, :orig_depot_path)
                            pop!(DEPOT_PATH)
                            append!(DEPOT_PATH, orig_depot_path)
                        end
                    end
                end
            end
        end
    end
end
