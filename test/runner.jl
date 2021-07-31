
if VERSION < v"1.2.0"
    @testset "get_test_dir - V1.0.5" begin
        # Stdlibs are not tested by other functions for V1.0.5
        stdlibname = "Pkg"
        ctx = Pkg.Types.Context()
        pkg = Pkg.PackageSpec(stdlibname)
        TestEnv.isinstalled!(ctx, pkg)
        delete!(ctx.env.manifest[stdlibname][1], "path")  # Remove path to force stdlib check
        testdir = joinpath(abspath(joinpath(dirname(Base.find_package(stdlibname)), "..")), "test")
        @test TestEnv.get_test_dir(ctx, pkg) == testdir
    end
end

@testset "activate do f [extras]" begin
    if VERSION >= v"1.4"  # can't check dependencies until julia 1.4
        direct_deps() = [v.name for (_,v) in Pkg.dependencies() if v.is_direct_dep]
        crc_deps = TestEnv.activate(direct_deps, "ChainRulesCore")
        @test "ChainRulesCore" ∈ crc_deps
        @test "FiniteDifferences" ∈ crc_deps
    end


    TestEnv.activate(()->(@eval using FiniteDifferences), "ChainRulesCore")
    @test isdefined(@__MODULE__, :FiniteDifferences)
end

@testset "activate [extras]" begin
    orig_project_toml_path = Base.active_project()
    TestEnv.activate("ChainRulesCore")
    new_project_toml_path = Base.active_project()
    @test new_project_toml_path != orig_project_toml_path

    @eval using StaticArrays
    @test isdefined(@__MODULE__, :StaticArrays)
end


VERSION >= v"1.3" && @testset "activate test/Project" begin
    Pkg.activate(mktempdir())
    # YAXArrays has a test/Project.toml, which contains CSV
    Pkg.add("YAXArrays")
    TestEnv.activate("YAXArrays")
    @eval using CSV
    @test isdefined(@__MODULE__, :CSV)
end

VERSION >= v"1.2" && @testset "activate do test/Project" begin
    Pkg.activate(mktempdir())
    # MCMCDiagnosticTools has a test/Project.toml, which contains FFTW
    Pkg.add("MCMCDiagnosticTools")

    TestEnv.activate(()->(@eval using FFTW), "MCMCDiagnosticTools")
    @test isdefined(@__MODULE__, :FFTW)
end