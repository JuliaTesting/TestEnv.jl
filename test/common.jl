@testset "common.jl" begin
    @testset "unnamed project" begin
        original_project = Base.active_project()
        Pkg.activate(@__DIR__)  # test folder is an unnamed project
        @test_throws TestEnv.TestEnvError TestEnv.activate()
        Pkg.activate(original_project)
    end
end