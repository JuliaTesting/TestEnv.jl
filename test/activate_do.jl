@testset "activate_do.jl" begin
    @testset "activate do f [extras]" begin
        mktempdir() do p
            Pkg.activate(p)
            Pkg.add(name="ChainRulesCore", version="1.0.2")

            orig_project = Base.active_project()

            direct_deps() = [v.name for (_,v) in Pkg.dependencies() if v.is_direct_dep]
            crc_deps = TestEnv.activate(direct_deps, "ChainRulesCore")
            @test "ChainRulesCore" ∈ crc_deps
            @test "FiniteDifferences" ∈ crc_deps

            TestEnv.activate("ChainRulesCore") do
                @eval using FiniteDifferences
            end
            @test isdefined(@__MODULE__, :FiniteDifferences)
            
            @test Base.active_project() == orig_project
        end
    end

    @testset "activate do test/Project" begin
        mktempdir() do p
            Pkg.activate(p)
            Pkg.add(name="MCMCDiagnosticTools", version="0.1.0")

            orig_project = Base.active_project()

            # MCMCDiagnosticTools has a test/Project.toml, which contains FFTW
            TestEnv.activate("MCMCDiagnosticTools") do
                @eval using FFTW
            end
            @test isdefined(@__MODULE__, :FFTW)
            
            @test Base.active_project() == orig_project
        end
    end
end
