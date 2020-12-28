using Pkg
using Test
using TestReports

if VERSION < v"1.2.0"
    @testset "gettestfilepath - V1.0.5" begin
        # Stdlibs are not tested by other functions for V1.0.5
        stdlibname = "Dates"
        ctx = Pkg.Types.Context()
        pkg = Pkg.PackageSpec(stdlibname)
        TestReports.isinstalled!(ctx, pkg)
        delete!(ctx.env.manifest[stdlibname][1], "path")  # Remove path to force stdlib check
        testfilepath = joinpath(abspath(joinpath(dirname(Base.find_package(stdlibname)), "..")), "test", "runtests.jl")
        @test TestReports.gettestfilepath(ctx, pkg) == testfilepath

        # PkgTestError when PkgSpec has missing info when finding path - V1.0.5 only
        pkgname = "PassingTests"
        Pkg.develop(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
        ctx = Pkg.Types.Context()
        pkg = Pkg.PackageSpec(pkgname)
        TestReports.isinstalled!(ctx, pkg)
        delete!(ctx.env.manifest["PassingTests"][1], "path")
        @test_throws TestReports.PkgTestError TestReports.gettestfilepath(ctx, pkg)
        Pkg.rm(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
    end
end

@testset "showerror" begin
    @test_throws TestReports.PkgTestError throw(TestReports.PkgTestError("Test"))
    @test sprint(showerror, TestReports.PkgTestError("Error text"), "") == "Error text"
end