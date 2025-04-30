@testset "activate_set.jl" begin
    @testset "activate [extras]" begin
        mktempdir() do p
            Pkg.activate(p)
            Pkg.add(PackageSpec(name="ChainRulesCore", version="1.0.2"))

            orig_project_toml_path = Base.active_project()
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            orig_load_path = Base.LOAD_PATH
            try
                TestEnv.activate("ChainRulesCore")
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path
                @test orig_load_path == Base.LOAD_PATH

                @eval using StaticArrays  # From ChainRulesCore [extras] Project.toml
                @test Base.invokelatest(isdefined, @__MODULE__, :StaticArrays)

                @eval using Compat  # from ChainRulesCore Project.toml
                @test Base.invokelatest(isdefined, @__MODULE__, :Compat)
            finally
                Pkg.activate(orig_project_toml_path)
                # No longer is enviroment active
                @test_throws ArgumentError @eval using OffsetArrays
            end
        end
    end

    @testset "activate test/Project" begin
        mktempdir() do p
            Pkg.activate(p)

            if VERSION >= v"1.4-"
                Pkg.add(PackageSpec(name="YAXArrays", version="0.1.3"))

                orig_project_toml_path = Base.active_project()
                push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
                orig_load_path = Base.LOAD_PATH
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
                    @test orig_load_path == Base.LOAD_PATH

                    @eval using CSV
                    @test Base.invokelatest(isdefined, @__MODULE__, :CSV)

                finally
                    Pkg.activate(orig_project_toml_path)
                end
            elseif VERSION >= v"1.2-"
                Pkg.add(PackageSpec(name="ConstraintSolver", version="0.6.10"))

                orig_project_toml_path = Base.active_project()
                push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
                orig_load_path = Base.LOAD_PATH
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
                    @test orig_load_path == Base.LOAD_PATH

                    @eval using JSON
                    @test Base.invokelatest(isdefined, @__MODULE__, :JSON)

                finally
                    Pkg.activate(orig_project_toml_path)
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
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            orig_load_path = Base.LOAD_PATH
            try
                Pkg.activate(joinpath(@__DIR__, "sources", "MainEnv"))
                TestEnv.activate()
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path
                @test orig_load_path == Base.LOAD_PATH
                @eval using MainEnv
                @test isdefined(@__MODULE__, :MainEnv)
                @test MainEnv.bar() == 42
            finally
                Pkg.activate(orig_project_toml_path)
            end
        end
    end
end
