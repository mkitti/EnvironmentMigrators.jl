"""
Welcome to EnvironmentMigrators.jl.

Use `EnvironmentMigrators.wizard()` for interactive use.

See also the following functions which are not exported.
* `list_shared_environments([depot])`
* `select_shared_environments([depot])`
* `backup_current_environment(; fileaction = cp)`
* `migrate_selected_environment(selected_environment; backup = true)`
* `wizard([depot])`
"""
module EnvironmentMigrators

using Pkg
using REPL.TerminalMenus
using Dates

"""
    list_shared_environments([depot])

List the top level shared environments in $(joinpath(DEPOT_PATH[1], "environments"))
"""
function list_shared_environments(depot = first(DEPOT_PATH))
    readdir(joinpath(depot, "environments"))
end

"""
    select_shared_environments([depot])

Present an interactive menu to select a shared environment to copy from.
Also provide options to select the current enviornment for backup or quit.
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
    backup_currernt_environments([depot]; fileaction=cp)

Backup the Project.toml and Manifest.toml to `backups/timestamp` where
`timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")``.

`fileaction` is a keyword parameter for a function that accepts two parameters.
`fileaction` defaults to `cp` for copy. An alternative is `mv` for move.
"""
function backup_current_environment(; fileaction=cp)
    @info "Current environment:"
    Pkg.status()
    current_env_project_toml = Base.active_project()
    current_dir = dirname(current_env_project_toml)
    current_env_manifest_toml = joinpath(current_dir, "Manifest.toml")
    mkpath(current_dir)
    if isfile(current_env_project_toml) || isfile(current_env_manifest_toml)
        timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")
        backup_dir = joinpath(current_dir, "backups", timestamp)
        mkpath(backup_dir)
        @info "Backing up Project.toml and Manifest.toml" current_env_project_toml current_env_manifest_toml backup_dir
        if isfile(current_env_project_toml)
            fileaction(current_env_project_toml, joinpath(backup_dir, "Project.toml"))
        else
            @info "Project.toml does not exist" current_env_project_toml
        end
        if isfile(current_env_manifest_toml)
            fileaction(current_env_manifest_toml, joinpath(backup_dir, "Manifest.toml"))
        else
            @info "Manifest.toml does not exist" current_env_manifest_toml
        end
    else
        @info "No existing Project.toml or Manifest.toml to backup" current_env_project_toml current_env_manifest_toml
    end
    nothing
end

"""
    migrate_selected_environment(selected_env)

Migrate the selected environment specified as a directory in selected_env to
the current active project.
"""
function migrate_selected_environment(selected_env; backup = true)
    if backup
        @info "Backing up the current environment" selected_env
        backup_current_environment(; fileaction=mv)
    end

    selected_project_toml = joinpath(selected_env, "Project.toml")
    selected_manifest_toml = joinpath(selected_env, "Manifest.toml")
    current_env = dirname(Base.active_project())
    if isfile(selected_project_toml)
        @info "Copying selected Project.toml to current environment" selected_project_toml current_env
        cp(selected_project_toml, joinpath(current_env, "Project.toml"))
    else
        @info "Selected Project.toml does not exist" selected_project_toml
    end
    if isfile(selected_manifest_toml)
        #@info "Copying selected Manifest.toml to current directory"
        #cp(selected_project_toml, joinpath(current_env, "Manifest.toml"))
    else
        @info "Selected Manifest.toml does not exist" selected_manifest_toml
    end
    try
        Pkg.status()
        Pkg.resolve()
        try
            Pkg.instantiate()
        catch err
            @error "An error occurred during Pkg.resolve()." err
            @info "Run `using Pkg; pkg\"instantiate\"` to view the error."
            @info "Run `using Pkg; rm\"PkgName\"` to remove problematic packages."
            return nothing
        end
    catch err
        @error "An error occurred during Pkg.resolve()." err
        @info "Run `using Pkg; Pkg.resolve()` to view the error."
        @info "Run `using Pkg; rm\"PkgName\"` to remove problematic packages."
        @info "Run `using Pkg; Pkg.instantiate()` afterwards."
        return nothing
    end
    @info "Migration successful"
    Pkg.status()
end

"""
    wizard([depot])

Run an interactive terminal based wizard.
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
    backup_current_environment(; fileaction)
    if selected_env != Base.active_project()
        migrate_selected_environment(selected_env; backup = false)
    end
    return nothing
end

function __init__()
    @info "Thank you for using EnvironmentMigrators.jl. Please run `EnvironmentMigrators.wizard()` to begin."
end

end