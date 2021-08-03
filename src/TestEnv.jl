module TestEnv
using Pkg
using Pkg: PackageSpec
using Pkg.Types: Context, ensure_resolved, is_project_uuid, write_env
using Pkg.Operations: manifest_info, manifest_resolve!, project_deps_resolve!
using Pkg.Operations: project_rel_path, project_resolve!

using Pkg.Types: Types, projectfile_path, manifestfile_path
using Pkg.Operations: gen_target_project
using Pkg.Operations: update_package_test!
using Pkg.Types: is_stdlib
using Pkg.Operations: sandbox, source_path, sandbox_preserve, abspath!


include("exceptions.jl")

include("activate.jl")
include("make_test_env.jl")
include("sandbox.jl")
include("test_dir.jl")

end