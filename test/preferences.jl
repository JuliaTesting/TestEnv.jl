# Preferences are only copied into the test environment on Julia 1.8 and later; see the
# `sandbox_preferences` helper in `src/julia-1.8/common.jl` and its siblings.
if VERSION >= v"1.8-"
    @testset "preferences.jl" begin
        @testset "activate: preferences from the package project" begin
            orig_project = Base.active_project()
            orig_load_path = copy(Base.LOAD_PATH)
            try
                Pkg.activate(joinpath(@__DIR__, "preferences", "PrefsTopLevel"))
                TestEnv.activate()

                # `with_load_path` must leave `LOAD_PATH` exactly as it found it
                @test Base.LOAD_PATH == orig_load_path

                @test Base.active_project() != orig_project

                # Read the sandbox's own preferences straight off disk, so the assertion does
                # not depend on whatever `LOAD_PATH` happens to look like. `Pkg` -- and hence
                # TestEnv -- writes to the first of `Base.preferences_names`.
                prefs_file = joinpath(dirname(Base.active_project()), first(Base.preferences_names))
                @test isfile(prefs_file)
                @test Pkg.TOML.parsefile(prefs_file)["PrefsTopLevel"]["setting"] == "top-level"

                # ...and Julia really does load them from the activated environment
                @test Base.get_preferences(Base.UUID("6f2c04ff-2c4a-4a4c-9a3f-1b04a2a2e6d1"))["setting"] == "top-level"
            finally
                Pkg.activate(orig_project)
            end
        end

        @testset "activate: test/ preferences win over the package project" begin
            orig_project = Base.active_project()
            orig_load_path = copy(Base.LOAD_PATH)
            try
                Pkg.activate(joinpath(@__DIR__, "preferences", "PrefsTestDir"))
                TestEnv.activate()

                @test Base.LOAD_PATH == orig_load_path

                prefs_file = joinpath(dirname(Base.active_project()), first(Base.preferences_names))
                @test isfile(prefs_file)

                prefs = Pkg.TOML.parsefile(prefs_file)["PrefsTestDir"]
                @test prefs["setting"] == "test-dir"
                # ...but the package project is still merged in behind it
                @test prefs["only_at_top_level"] == "yes"
                @test Base.get_preferences(Base.UUID("3a5b3ec6-2b25-4f0c-9c6b-1e0f5b1a7c2d"))["setting"] == "test-dir"
            finally
                Pkg.activate(orig_project)
            end
        end

        @testset "activate do: preferences from the package project" begin
            orig_project = Base.active_project()
            try
                Pkg.activate(joinpath(@__DIR__, "preferences", "PrefsTopLevel"))
                prefs = TestEnv.activate("PrefsTopLevel") do
                    prefs_file = joinpath(dirname(Base.active_project()), first(Base.preferences_names))
                    Pkg.TOML.parsefile(prefs_file)["PrefsTopLevel"]
                end
                @test prefs["setting"] == "top-level"
            finally
                Pkg.activate(orig_project)
            end
        end

        @testset "activate do: test/ preferences win over the package project" begin
            orig_project = Base.active_project()
            try
                Pkg.activate(joinpath(@__DIR__, "preferences", "PrefsTestDir"))
                prefs = TestEnv.activate("PrefsTestDir") do
                    prefs_file = joinpath(dirname(Base.active_project()), first(Base.preferences_names))
                    Pkg.TOML.parsefile(prefs_file)["PrefsTestDir"]
                end
                @test prefs["setting"] == "test-dir"
                @test prefs["only_at_top_level"] == "yes"
            finally
                Pkg.activate(orig_project)
            end
        end

        @testset "activate: no preferences means no preferences file" begin
            orig_project = Base.active_project()
            try
                Pkg.activate(joinpath(@__DIR__, "preferences", "PrefsNone"))
                # Only meaningful when the surrounding environment contributes no
                # preferences of its own -- those legitimately get copied into the sandbox.
                surroundings_are_clean = isempty(Base.get_preferences())
                TestEnv.activate()

                @test isempty(Base.get_preferences(Base.UUID("8ec4a1e1-5c93-4b52-96f2-0c5f0f4e2d3b")))
                if surroundings_are_clean
                    @test !isfile(joinpath(dirname(Base.active_project()), first(Base.preferences_names)))
                end
            finally
                Pkg.activate(orig_project)
            end
        end
    end
end
