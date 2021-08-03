using Pkg
using TestEnv
using Test

@testset "TestEnv.jl" begin
    include("activate_do.jl")
    include("activate_set.jl")
end
