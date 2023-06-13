@testset "activate_do.jl" begin
    @testset "activate do f [extras]" begin
        mktempdir() do p
            Pkg.activate(p)
            Pkg.add(PackageSpec(name="ChainRulesCore", version="1.0.2"))

            orig_project = Base.active_project()

            if VERSION >= v"1.4"
                direct_deps() = [v.name for (_,v) in Pkg.dependencies() if v.is_direct_dep]
                crc_deps = TestEnv.activate(direct_deps, "ChainRulesCore")
                @test "ChainRulesCore" ∈ crc_deps
                @test "FiniteDifferences" ∈ crc_deps
            end

            TestEnv.activate("ChainRulesCore") do
                @eval using FiniteDifferences
            end
            @test isdefined(@__MODULE__, :FiniteDifferences)
            
            # We use endswith here because on MacOS GitHub runners for some reasons the paths are slightly different
            # We also skip on Julia 1.2 and 1.3 on Windows because it is using 8 character shortened paths in one case
            if !((VERSION==v"1.2" || VERSION==v"1.3") && Sys.iswindows())
                @test endswith(Base.active_project(), orig_project)
            end
        end
    end

    @testset "activate do test/Project" begin
        mktempdir() do p
            Pkg.activate(p)

            if VERSION >= v"1.4"
                Pkg.add(PackageSpec(name="MCMCDiagnosticTools", version="0.1.0"))

                orig_project = Base.active_project()

                # MCMCDiagnosticTools has a test/Project.toml, which contains FFTW
                TestEnv.activate("MCMCDiagnosticTools") do
                    @eval using FFTW
                end
                @test isdefined(@__MODULE__, :FFTW)
                
                @test endswith(Base.active_project(), orig_project)
            elseif VERSION >= v"1.2"
                Pkg.add(PackageSpec(name="ConstraintSolver", version="0.6.10"))

                orig_project = Base.active_project()

                # ConstraintSolver has a test/Project.toml, which contains Combinatorics
                TestEnv.activate("ConstraintSolver") do
                    @eval using Combinatorics
                end
                @test isdefined(@__MODULE__, :Combinatorics)
                
                # We use endswith here because on MacOS GitHub runners for some reasons the paths are slightly different
                # We also skip on Windows because it is using 8 character shortened paths in one case
                if !Sys.iswindows()
                    @test endswith(Base.active_project(), orig_project)
                end
            end            
        end
    end
end
