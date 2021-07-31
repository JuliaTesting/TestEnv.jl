@testset "activate do f" begin
    if VERSION >= v"1.4"  # can't check dependencies until julia 1.4
        direct_deps() = [v.name for (_,v) in Pkg.dependencies() if v.is_direct_dep]
        crc_deps = TestEnv.activate(direct_deps, "ChainRulesCore")
        @test "ChainRulesCore" ∈ crc_deps
        @test "FiniteDifferences" ∈ crc_deps
    end


    TestEnv.activate(()->(@eval using FiniteDifferences), "ChainRulesCore")
    @test isdefined(@__MODULE__, :FiniteDifferences)
end

if VERSION < v"1.2.0"
    @testset "gettestdir - V1.0.5" begin
        # Stdlibs are not tested by other functions for V1.0.5
        stdlibname = "Pkg"
        ctx = Pkg.Types.Context()
        pkg = Pkg.PackageSpec(stdlibname)
        TestEnv.isinstalled!(ctx, pkg)
        delete!(ctx.env.manifest[stdlibname][1], "path")  # Remove path to force stdlib check
        testdir = joinpath(abspath(joinpath(dirname(Base.find_package(stdlibname)), "..")), "test")
        @test TestEnv.gettestdir(ctx, pkg) == testdir
    end
end

