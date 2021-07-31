module TestEnv
using Pkg
using Pkg: PackageSpec
using Pkg.Types: Context, ensure_resolved, is_project_uuid
using Pkg.Operations: manifest_info, manifest_resolve!, project_deps_resolve!
using Pkg.Operations: project_rel_path, project_resolve!

include("runner.jl")

end