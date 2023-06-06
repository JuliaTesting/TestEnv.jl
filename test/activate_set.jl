@testset "activate_set.jl" begin
    @testset "activate [extras]" begin
        orig_project_toml_path = Base.active_project()
        try
            TestEnv.activate("ChainRulesCore")
            new_project_toml_path = Base.active_project()
            @test new_project_toml_path != orig_project_toml_path

            @eval using StaticArrays
            @test isdefined(@__MODULE__, :StaticArrays)
        finally
            Pkg.activate(orig_project_toml_path)
        end
    end

    @testset "activate test/Project" begin
        orig_project_toml_path = Base.active_project()
        try
            # YAXArrays has a test/Project.toml, which contains CSV
            TestEnv.activate("YAXArrays")
            new_project_toml_path = Base.active_project()
            @test new_project_toml_path != orig_project_toml_path

            @eval using CSV
            @test isdefined(@__MODULE__, :CSV)
        finally
            Pkg.activate(orig_project_toml_path)
        end
    end
end
