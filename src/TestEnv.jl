module TestEnv
using Pkg
using Pkg: PackageSpec
using Pkg.Types: Context, ensure_resolved, is_project_uuid, write_env
using Pkg.Types: Types, projectfile_path, manifestfile_path, SHA1
using Pkg.Operations: manifest_info, manifest_resolve!, project_deps_resolve!
using Pkg.Operations: project_rel_path, project_resolve!
using Pkg.Operations: with_dependencies_loadable_at_toplevel, find_installed
using Pkg.Operations: get_deps, collect_target_deps!, add_or_develop
using Pkg.Operations: resolve_versions!, apply_versions, build_versions, prune_manifest
using UUIDs

include("common.jl")
include("activate_do.jl")
include("activate_set.jl")

end