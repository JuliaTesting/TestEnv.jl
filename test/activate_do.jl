@testset "activate_do.jl" begin
    @testset "activate do f [extras]" begin
        direct_deps() = [v.name for (_,v) in Pkg.dependencies() if v.is_direct_dep]
        crc_deps = TestEnv.activate(direct_deps, "ChainRulesCore")
        @test "ChainRulesCore" ∈ crc_deps
        @test "FiniteDifferences" ∈ crc_deps

        TestEnv.activate("ChainRulesCore") do
            @eval using FiniteDifferences
        end
        @test isdefined(@__MODULE__, :FiniteDifferences)
    end

    @testset "activate do test/Project" begin
        # MCMCDiagnosticTools has a test/Project.toml, which contains FFTW
        TestEnv.activate("MCMCDiagnosticTools") do
            @eval using FFTW
        end
        @test isdefined(@__MODULE__, :FFTW)
    end
end