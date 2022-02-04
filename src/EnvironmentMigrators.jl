"""
Welcome to EnvironmentMigrators.jl.

Use `EnvironmentMigrators.wizard()` for interactive use.

# High level interface (unexported)
* `list_shared_environments([depot])`
* `select_shared_environments([depot])`
* `backup_current_environment(; fileaction = cp)`
* `migrate_selected_environment(selected_environment; backup = true)`
* `migrate_current_environment_to(path)`
* `wizard([depot])`

# Exported types
* `SimpleEnvironmentMigrator`
* `SimpleBackupOnlyEnvironmentMigrator`

# Exported methods
* `migrate(m::EnvironmentMigrators.AbstractEnvironmentMigrator)`
* `backup(m::EnvironmentMigrators.AbstractEnvironmentMigrator)`
"""
module EnvironmentMigrators

# https://github.com/JuliaLang/julia/pull/34896
@static if isdefined(Base, :Experimental) &&
           isdefined(Base.Experimental, Symbol("@optlevel"))
    Base.Experimental.@optlevel 1
end

using Pkg
using REPL.TerminalMenus
using Dates

export SimpleEnvironmentMigrator, SimpleBackupOnlyEnvironmentMigrator
export migrate, backup

include("types.jl")

"""
    list_shared_environments([depot])

List the top level shared environments in $(joinpath(DEPOT_PATH[1], "environments")).
`depot` defaults to `first(DEPOT_PATH)`.
"""
function list_shared_environments(depot = first(DEPOT_PATH))
    shared_environments = joinpath(depot, "environments")
    if !isdir(shared_environments)
        return String[]
    else
        return readdir(shared_environments)
    end
end

"""
    select_shared_environments([depot])

Present an interactive menu to select a shared environment to copy from.
Also provide options to select the current enviornment for backup or quit.
`depot` defaults to `first(DEPOT_PATH)`.
"""
function select_shared_environments(depot = first(DEPOT_PATH))
    envs = list_shared_environments()
    options = copy(envs)
    for idx in eachindex(options)
        if options[idx] == "v$(VERSION.major).$(VERSION.minor)"
            options[idx] = options[idx] * "(current version)"
        end
    end
    push!(options, "Backup the current environment: $(Base.active_project()).")
    push!(options, "Quit. Do Nothing.")
    menu = RadioMenu(options)
    println("Use the arrow keys to move the cursor. Press enter to select.")
    println("Please select a shared environment to copy to $(Base.active_project()):")
    menu_idx = request(menu)
    if menu_idx <= length(envs)
        return joinpath(depot, "environments", envs[menu_idx])
    elseif menu_idx == length(envs) + 1
        return Base.active_project()
    elseif menu_idx == length(options)
        @info "Quiting. No action taken."
        return ""
    end
end

"""
    backup_current_environments([depot]; fileaction=cp)

Backup the Project.toml and Manifest.toml to `backups/timestamp` where
`timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")``.

`fileaction` is a keyword parameter for a function that accepts two parameters.
`fileaction` defaults to `cp` for copy. An alternative is `mv` for move.
`depot` defaults to `first(DEPOT_PATH)`.
"""
function backup_current_environment(; fileaction=cp)
    @info "Current environment:"
    m = SimpleBackupOnlyEnvironmentMigrator(fileaction)
    Pkg.activate(m.target_project_toml)
    Pkg.status()
    backup(m)
end

"""
    migrate_selected_environment(selected_env)

Migrate the selected environment specified as a directory in selected_env to
the current active project.

`selected_env` should be the absolute path to an environment _directory_.
"""
function migrate_selected_environment(selected_env; backup = true)
    if !isdir(selected_env) && isfile(selected_env) && endswith(selected_env, "Project.toml")
        selected_env = dirname(selected_env)
    end
    selected_project_toml = joinpath(selected_env, "Project.toml")
    selected_julia_project_toml = joinpath(selected_env, "JuliaProject.toml")
    if isfile(selected_julia_project_toml)
        selected_project_toml = selected_julia_project_toml
    end
    selected_manifest_toml = joinpath(selected_env, "Manifest.toml")
    selected_julia_manifest_toml = joinpath(selected_env, "JuliaManifest.toml")
    if isfile(selected_julia_manifest_toml)
        selected_manifest_toml = selected_julia_manifest_toml
    end
    m = SimpleEnvironmentMigrator(selected_project_toml, selected_manifest_toml)
    migrate(m; backup = backup)
    return nothing
end

"""
    wizard([depot])

Run an interactive terminal based wizard.

`depot` defaults to `first(DEPOT_PATH)`.
"""
function wizard(depot = first(DEPOT_PATH))
    selected_env = select_shared_environments(depot)
    if isempty(selected_env)
        return nothing
    end
    fileaction = if selected_env == Base.active_project()
        @info "Backing up the current environment" Base.active_project()
        cp
    else
        mv
    end
    backup_current_environment(; fileaction=fileaction)
    if selected_env != Base.active_project()
        migrate_selected_environment(selected_env; backup = false)
    end
    return nothing
end

"""
    migrate_current_environment_to(path::AbstractString)

Migrate the current environment to the indicated path.
"""
function migrate_current_environment_to(path::AbstractString; update = false)
    mkpath(path)
    source_project_toml, source_manifest_toml = get_current_project_and_manifest()
    target_project_toml, target_manifest_toml = joinpath.(path, basename.((source_project_toml, source_manifest_toml)))
    m = SimpleEnvironmentMigrator(source_project_toml, source_manifest_toml,
                                  target_project_toml, target_manifest_toml)
    migrate(m; update = update)
end

function __init__()
    @info "Thank you for using EnvironmentMigrators.jl. Please run `EnvironmentMigrators.wizard()` to begin."
end

end