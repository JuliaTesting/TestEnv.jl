@testset "activate_do.jl" begin
    @testset "activate do f [extras]" begin
        TestEnv.activate("ChainRulesCore") do
            @eval using FiniteDifferences
        end
        @test isdefined(@__MODULE__, :FiniteDifferences)
    end
end