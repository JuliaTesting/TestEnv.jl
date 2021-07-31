module TestEnv
using Pkg
using Pkg: PackageSpec
using Pkg.Types: Context, ensure_resolved, is_project_uuid, write_env
using Pkg.Operations: manifest_info, manifest_resolve!, project_deps_resolve!
using Pkg.Operations: project_rel_path, project_resolve!

using Pkg.Types: Types, projectfile_path, manifestfile_path

# Version specific imports
@static if VERSION >= v"1.4.0"
    using Pkg.Operations: gen_target_project
else
    using Pkg.Operations: with_dependencies_loadable_at_toplevel
end
@static if VERSION >= v"1.2.0"
    using Pkg.Types: is_stdlib
    using Pkg.Operations: sandbox, source_path, update_package_test! , sandbox_preserve, abspath!
else
    using Pkg.Operations: find_installed
    using Pkg.Types: SHA1
end


include("exceptions.jl")

include("activate.jl")
include("make_test_env.jl")
include("sandbox.jl")
include("test_dir.jl")

end