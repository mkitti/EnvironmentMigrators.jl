# EnvironmentMigrators

[![Build Status](https://github.com/mkitti/EnvironmentMigrators.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/mkitti/EnvironmentMigrators.jl/actions/workflows/CI.yml?query=branch%3Amain)

This package is to facilitate the copying of Julia shared environments, particularly between versions, as well as backing up of the current environment.

# Installation

In the Julia REPL,
`] add EnvironmentMigrators`

# Interactive Use

For interactive use, invoke `EnvironmentMigrators.wizard()`.

```julia

julia> using EnvironmentMigrators

julia> EnvironmentMigrators.wizard()
Use the arrow keys to move the cursor. Press enter to select.
Please select a shared environment to copy to C:\Users\KITTIS~1\AppData\Local\Temp\jl_CPGp07\Project.toml:
   __pluto_boot_1.6.0
   v1.5
   v1.6
 > v1.7(current version)
   v1.8
   Backup the current environment: C:\Users\KITTIS~1\AppData\Local\Temp\jl_CPGp07\Project.toml.
   Quit. Do Nothing.
[ Info: Current environment:
      Status `C:\Users\kittisopikulm\AppData\Local\Temp\jl_CPGp07\Project.toml`
  [e51d7f76] EnvironmentMigrators v0.1.0 `C:\Users\kittisopikulm\.julia\dev\EnvironmentMigrators`
┌ Info: Backing up Project.toml and Manifest.toml
│   current_env_project_toml = "C:\\Users\\KITTIS~1\\AppData\\Local\\Temp\\jl_CPGp07\\Project.toml"
│   current_env_manifest_toml = "C:\\Users\\KITTIS~1\\AppData\\Local\\Temp\\jl_CPGp07\\Manifest.toml"
└   backup_dir = "C:\\Users\\KITTIS~1\\AppData\\Local\\Temp\\jl_CPGp07\\backups\\2022-02-03_16_47_33"
┌ Info: Copying selected Project.toml to current environment
│   selected_project_toml = "C:\\Users\\kittisopikulm\\.julia\\environments\\v1.7\\Project.toml"
└   current_env = "C:\\Users\\KITTIS~1\\AppData\\Local\\Temp\\jl_CPGp07"
      Status `C:\Users\kittisopikulm\AppData\Local\Temp\jl_CPGp07\Project.toml
      Status `C:\Users\kittisopikulm\AppData\Local\Temp\jl_CPGp07\Project.toml`
  [6e4b80f9] BenchmarkTools
  ...
    Updating `C:\Users\kittisopikulm\AppData\Local\Temp\jl_CPGp07\Project.toml`
  [6e4b80f9] + BenchmarkTools v1.2.2
  ...
    Updating `C:\Users\kittisopikulm\AppData\Local\Temp\jl_CPGp07\Manifest.toml`
  [1520ce14] + AbstractTrees v0.3.4
  [79e6a3ab] + Adapt v3.3.3
  [4fba245c] + ArrayInterface v4.0.2
  [6e4b80f9] + BenchmarkTools v1.2.2
...
[ Info: Migration successful
      Status `C:\Users\kittisopikulm\AppData\Local\Temp\jl_CPGp07\Project.toml`
...
```

```

# Non-interactive Use

```
julia.exe -e '
using Pkg
Pkg.activate(mktempdir())
Pkg.add(\"EnvironmentMigrators\")
using EnvironmentMigrators
EnvironmentMigrators.migrate_selected_environment(joinpath(DEPOT_PATH[1], \"environments\", \"v1.6\"))
'
```

# Manually moving environments without this package

To manually move environments, copy the `Project.toml` and `Manifest.toml` from the old environment to the new environment, 
backing up Project.toml and Manifest.toml as needed. The default environments live in `joinpath(first(DEPOT_PATH), "environments")`.
This is usually `~/.julia/environments` or `C:\Users\YourUsername\.julia\environments`.

It is generally not recommended to heavily populate the default version-specific environments. Rather use project specific environments
by using changing directories to your project folder and then `] activate`.

```julia
julia> environments_dir = joinpath(first(DEPOT_PATH), "environments")
"C:\\Users\\kittisopikulm\\.julia\\environments"

julia> readdir(environments_dir)
5-element Vector{String}:
 "__pluto_boot_1.6.0"
 "v1.5"
 "v1.6"
 "v1.7"
 "v1.8"

julia> v17_project = joinpath(environments_dir, "v1.7", "Project.toml")
"C:\\Users\\kittisopikulm\\.julia\\environments\\v1.7\\Project.toml"

julia> v17_manifest = joinpath(environments_dir, "v1.7", "Manifest.toml")
"C:\\Users\\kittisopikulm\\.julia\\environments\\v1.7\\Manifest.toml"

julia> v18_project = joinpath(environments_dir, "v1.8", "Project.toml")
"C:\\Users\\kittisopikulm\\.julia\\environments\\v1.8\\Project.toml"

julia> v18_manifest = joinpath(environments_dir, "v1.8", "Manifest.toml")
"C:\\Users\\kittisopikulm\\.julia\\environments\\v1.8\\Manifest.toml"

julia> timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")
"2022-02-03_16_30_38"

julia> backup_dir = joinpath(dirname(v18_project), "backups", timestamp)

julia> mkpath(backup_dir)
"C:\\Users\\kittisopikulm\\.julia\\environments\\v1.8\\backups\\2022-02-03_16_30_38"

julia> isfile(v18_project) && mv(v18_project, joinpath(backup_dir, "Project.toml"))
false

julia> isfile(v18_manifest) && mv(v18_manifest, joinpath(backup_dir, "Manifest.toml"))
"C:\\Users\\kittisopikulm\\.julia\\environments\\v1.8\\backups\\2022-02-03_16_30_38\\Manifest.toml"

julia> using Pkg

julia> Pkg.activate(v18_project)

julia> Pkg.resolve()

julia> Pkg.instantiate()

```
