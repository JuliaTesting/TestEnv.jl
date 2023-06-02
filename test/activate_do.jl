@testset "activate_do.jl" begin
    @testset "activate do f [extras]" begin
        orig_project = Base.active_project()
        TestEnv.activate("ChainRulesCore") do
            @eval using FiniteDifferences
        end
        @test isdefined(@__MODULE__, :FiniteDifferences)
        
        @test Base.active_project() == orig_project
    end
end
