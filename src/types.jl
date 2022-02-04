abstract type AbstractEnvironmentMigrator end;

mutable struct SimpleEnvironmentMigrator <: AbstractEnvironmentMigrator
    source_project_toml::Union{AbstractString, Nothing}
    source_manifest_toml::Union{AbstractString, Nothing}
    target_project_toml::AbstractString
    target_manifest_toml::AbstractString
end
function SimpleEnvironmentMigrator(source_project_toml, source_manifest_toml)
    project_toml = Base.active_project()
    manifest_toml = joinpath(dirname(project_toml), "Manifest.toml")
    SimpleEnvironmentMigrator(source_project_toml, source_manifest_toml, project_toml, manifest_toml)
end
SimpleEnvironmentMigrator() = SimpleEnvironmentMigrator(nothing, nothing)
source_project_toml(m::SimpleEnvironmentMigrator) = m.source_project_toml
source_manifest_toml(m::SimpleEnvironmentMigrator) = m.source_manifest_toml
target_project_toml(m::SimpleEnvironmentMigrator) = m.target_project_toml
target_manifest_toml(m::SimpleEnvironmentMigrator) = m.target_manifest_toml
fileaction(m::SimpleEnvironmentMigrator) = m.source_project_toml === nothing ? cp : mv

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

function backup(m::AbstractEnvironmentMigrator)
    @assert dirname(target_project_toml(m)) == dirname(target_manifest_toml(m))
    current_dir = dirname(target_project_toml(m))
    if isfile(target_project_toml(m)) || isfile(target_manifest_toml(m))
        timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")
        backup_dir = joinpath(current_dir, "backups", timestamp)
        mkpath(backup_dir)
        @info "Backing up Project.toml and Manifest.toml" target_project_toml(m) target_manifest_toml(m) backup_dir
        _fileaction = fileaction(m)
        if isfile(target_project_toml(m))
            _fileaction(target_project_toml(m), joinpath(backup_dir, "Project.toml"))
        else
            @info "Project.toml does not exist" target_project_toml(m)
        end
        if isfile(target_manifest_toml(m))
            _fileaction(target_manifest_toml(m), joinpath(backup_dir, "Manifest.toml"))
        else
            @info "Manifest.toml does not exist" target_manifest_toml(m)
        end
    else
        @info "No existing Project.toml or Manifest.toml to backup" target_project_toml(m) target_manifest_toml(m)
    end
    return nothing
end

const SimpleEnvironmentMigrators = Union{SimpleEnvironmentMigrator, SimpleBackupOnlyEnvironmentMigrator}

function migrate(m::SimpleEnvironmentMigrators; backup = true)
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
    @info "Updating"
    Pkg.update()
    @info "Migration complete and environment updated. Have a nice day!" _target_project_toml
    return nothing
end