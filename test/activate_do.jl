@testset "activate_do.jl" begin
    @testset "activate do f [extras]" begin
        TestEnv.activate("ChainRulesCore") do
            @eval using FiniteDifferences
        end
        @test isdefined(@__MODULE__, :FiniteDifferences)
    end

    @testset "activate do test/Project" begin
        # MCMCDiagnosticTools has a test/Project.toml, which contains FFTW
        TestEnv.activate("ConstraintSolver") do
            @eval using Combinatorics
        end
        @test isdefined(@__MODULE__, :Combinatorics)
    end
end