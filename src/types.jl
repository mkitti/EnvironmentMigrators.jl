"""
    get_current_project_and_manifest()

Return the current project and manifest TOML files.

# Implementation details

* `Base.active_project()` is used to determine the location the current (Julia)Project.toml
* JuliaManifest.toml takes precedent over Manifest.toml in the same directory as the Project.toml 
"""
function get_current_project_and_manifest()
    project_toml = Base.active_project()
    julia_manifest_toml = joinpath(dirname(project_toml), "JuliaManifest.toml")
    if isfile(julia_manifest_toml)
        manifest_toml = julia_manifest_toml
    else
        manifest_toml = joinpath(dirname(project_toml), "Manifest.toml")
    end
    project_toml, manifest_toml
end

"""
    AbstractEnvironmentMigrator

Base abstract type for EnvironmentMigrators.

# Interface:
* `source_project_toml(m::AbstractEnvironmentMigrator)`
    - return path of (Julia)Project.toml to copy from or `nothing` if there is no source
* `source_manifest_toml(m::AbstractEnvironmentMigrator)`
    - return path of (Julia)Manifest.toml to copy from or `nothing` if there is no source
* `target_project_toml(m::AbstractEnvironmentMigrator)`
    - return path of (Julia)Project.toml to backup and to which to copy
* `target_manifest_toml(m::AbstractEnvironmentMigrator)`
    - return path of (Julia)Manifest.toml to backup and to which to copy
* `fileaction(m::AbstractEnvironmentMigrator)`
    - action to take during backup operations
* `backup(m::AbstractEnvironmentMigrator)`
    - save a copy of the target environment in a timestamped subfolder
* `migrate(m::AbstractEnvironmentMigrator; backup = true, update = true)`
    - migrate project and manifest files from source to target

# Subtypes:
* `SimpleEnvironmentMigrator`
    - set source and target project and manifest files as fields
* `SimpleBackupOnlyEnvironmentMigrator`
    - set target project and manifest files as fields
"""
abstract type AbstractEnvironmentMigrator end;

"""
    SimpleEnvironmentMigrator([source_project_toml, source_target_toml], [target_project_toml, target_manifest_toml])

An `AbstractEnvironmentMigrator` where one can set source and target project and manifest files as fields.
If `source_project_toml` and `source_manifest_toml` are not specified, they will be `nothing`.
If `target_project_toml` and `target_manifest_toml` are not specified, they will be set to the current environment.

# Fields

* `source_project_toml`
* `source_manifest_toml`
* `target_project_toml`
* `target_manifest_toml`

# Method details

`fileaction(m)` will return `cp` if `source_project_toml` is `nothing` or `mv` otherwise.
"""
mutable struct SimpleEnvironmentMigrator <: AbstractEnvironmentMigrator
    source_project_toml::Union{AbstractString, Nothing}
    source_manifest_toml::Union{AbstractString, Nothing}
    target_project_toml::AbstractString
    target_manifest_toml::AbstractString
end
function SimpleEnvironmentMigrator(source_project_toml, source_manifest_toml)
    project_toml, manifest_toml = get_current_project_and_manifest()
    SimpleEnvironmentMigrator(source_project_toml, source_manifest_toml, project_toml, manifest_toml)
end
SimpleEnvironmentMigrator() = SimpleEnvironmentMigrator(nothing, nothing)
source_project_toml(m::SimpleEnvironmentMigrator) = m.source_project_toml
source_manifest_toml(m::SimpleEnvironmentMigrator) = m.source_manifest_toml
target_project_toml(m::SimpleEnvironmentMigrator) = m.target_project_toml
target_manifest_toml(m::SimpleEnvironmentMigrator) = m.target_manifest_toml
fileaction(m::SimpleEnvironmentMigrator) = m.source_project_toml === nothing ? cp : mv

"""
    SimpleBackupOnlyEnvironmentMigrator{F}([target_project_toml, target_manifest_toml], fileaction::F)

`AbstractEnvironmentMigrator` only for backing up the target project and manifest tomls to a timestamped folder.
The target project and manifest tomls will default to the current project and manifest tomls.
"""
mutable struct SimpleBackupOnlyEnvironmentMigrator{F} <: AbstractEnvironmentMigrator
    target_project_toml::AbstractString
    target_manifest_toml::AbstractString
    fileaction::F
end
function SimpleBackupOnlyEnvironmentMigrator{F}(fileaction::F) where F
    project_toml = Base.active_project()
    manifest_toml = joinpath(dirname(project_toml), "Manifest.toml")
    SimpleBackupOnlyEnvironmentMigrator{F}(project_toml, manifest_toml, fileaction)
end
SimpleBackupOnlyEnvironmentMigrator() = SimpleBackupOnlyEnvironmentMigrator{typeof(cp)}(cp)
SimpleBackupOnlyEnvironmentMigrator(fileaction::F) where F = SimpleBackupOnlyEnvironmentMigrator{F}(fileaction)

source_project_toml(::SimpleBackupOnlyEnvironmentMigrator) = nothing
source_manifest_toml(::SimpleBackupOnlyEnvironmentMigrator) = nothing
target_project_toml(m::SimpleBackupOnlyEnvironmentMigrator) = m.target_project_toml
target_manifest_toml(m::SimpleBackupOnlyEnvironmentMigrator) = m.target_manifest_toml
fileaction(m::SimpleBackupOnlyEnvironmentMigrator{F}) where F = m.fileaction

"""
    backup(m::AbstractEnvironmentMigrator)

Backup an environment. Typically, this involves copying the Project.toml and Manifest.toml
to a time-stamped backup subfolder.

# Extended Help

The standard backup procedure is as follows.
1. Check that the target project and manifest TOMLs are in the same directory.
2. Check that one of either the project or manifest TOMLs exist
3. Create a time stamp in the format "yyyy-mm-dd_HH_MM_SS
4. Create a subpath in the same directory as the project TOML called `backups/[timestamp]`
5. Copy (or move) the project and manifest TOMLs to the backup path if they exist.
"""
function backup(m::AbstractEnvironmentMigrator)
    @assert dirname(target_project_toml(m)) == dirname(target_manifest_toml(m))
    current_dir = dirname(target_project_toml(m))
    if isfile(target_project_toml(m)) || isfile(target_manifest_toml(m))
        timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")
        backup_dir = joinpath(current_dir, "backups", timestamp)
        mkpath(backup_dir)
        @info "Backing up Project.toml and Manifest.toml" target_project_toml(m) target_manifest_toml(m) backup_dir
        _fileaction = fileaction(m)
        for toml in (target_project_toml(m), target_manifest_toml(m))
            if isfile(toml)
                _fileaction(toml, joinpath(backup_dir, basename(toml)))
            else
                @info "$toml does not exist" toml
            end
        end
    else
        @info "No existing Project.toml or Manifest.toml to backup" target_project_toml(m) target_manifest_toml(m)
    end
    return nothing
end

const SimpleEnvironmentMigrators = Union{SimpleEnvironmentMigrator, SimpleBackupOnlyEnvironmentMigrator}

"""
    migrate(m::AbstractEnvironmentMigrator; backup = true, update = true)

Move an environment from one place to another.
`backup` - whether to perform a backup of the target environment (`true`) or not (`false`).
`update` - whether to perform an update of the source environment (`true`) or not (`false`).

# Extended Help

The typical migration procedure is as follows.

1. Backup the target environment by moving the files if indicated.
2. Copy the (Julia)Project.toml from the source to the target environment.
3. Copy the (Julia)Manifest.toml from the source to the target environment.
4. Activate the target environment
5. `Pkg.status()`
6. `Pkg.upgrade_manifest()` - skip if error
7. `Pkg.resolve()`
8. `Pkg.instantiate()`
9. `Pkg.status()`
10. `Pkg.update()`
"""
function migrate(m::SimpleEnvironmentMigrators; backup = true, update = true)
    if backup
        @info "Backing up the current environment" m
        EnvironmentMigrators.backup(m)
    end

    selected_project_toml = source_project_toml(m)
    selected_manifest_toml = source_manifest_toml(m)
    _target_project_toml = target_project_toml(m)
    _target_manifest_toml = target_manifest_toml(m)

    if selected_project_toml === nothing || selected_manifest_toml === nothing
        @info "No migration target. No further action."
        return;
    end

    if isfile(selected_project_toml)
        @info "Copying selected Project.toml to current environment" selected_project_toml _target_project_toml
        cp(selected_project_toml, _target_project_toml)
    else
        @info "Selected Project.toml does not exist" selected_project_toml
    end
    if isfile(selected_manifest_toml)
        @info "Copying selected Manifest.toml to current directory" selected_manifest_toml _target_manifest_toml
        cp(selected_manifest_toml, _target_manifest_toml)
    else
        @info "Selected Manifest.toml does not exist" selected_manifest_toml
    end
    try
        Pkg.activate(_target_project_toml)
        Pkg.status()
        try
            Pkg.upgrade_manifest()
        catch err
        end
        Pkg.resolve()
        try
            Pkg.instantiate()
        catch err
            @error "An error occurred during Pkg.instantiate()." err
            @info "Run `using Pkg; pkg\"instantiate\"` to view the error."
            @info "Run `using Pkg; pkg\"rm PkgName\"` to remove problematic packages."
            @info "Run `using Pkg; pkg\"update\"` to update to the latest package versions."
            return nothing
        end
    catch err
        @error "An error occurred during Pkg.resolve()." err
        @info "Run `using Pkg; Pkg.resolve()` to view the error."
        @info "Run `using Pkg; pkg\"rm PkgName\"` to remove problematic packages."
        @info "Run `using Pkg; Pkg.instantiate()` afterwards."
        @info "Run `using Pkg; pkg\"update\"` to update to the latest package versions."
        return nothing
    end
    @info "Migration successful"
    Pkg.status()
    if update
        @info "Updating"
        Pkg.update()
    end
    @info "Migration complete and environment updated. Have a nice day!" _target_project_toml
    return nothing
end