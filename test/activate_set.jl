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
                @test isdefined(@__MODULE__, :StaticArrays)

                @eval using Compat  # from ChainRulesCore Project.toml
                @test isdefined(@__MODULE__, :StaticArrays)
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
            Pkg.add(PackageSpec(name="YAXArrays", version="0.1.3"))

            orig_project_toml_path = Base.active_project()
            push!(LOAD_PATH, mktempdir())  # put something weird in LOAD_PATH for testing
            orig_load_path = Base.LOAD_PATH
            try
                # YAXArrays has a test/Project.toml, which contains CSV
                TestEnv.activate("YAXArrays")
                new_project_toml_path = Base.active_project()
                @test new_project_toml_path != orig_project_toml_path
                @test orig_load_path == Base.LOAD_PATH

                @eval using CSV
                @test isdefined(@__MODULE__, :CSV)

            finally
                Pkg.activate(orig_project_toml_path)
            end
        end

        # https://github.com/JuliaTesting/TestEnv.jl/issues/26
        @test isdefined(TestEnv, :isfixed)
    end
end
