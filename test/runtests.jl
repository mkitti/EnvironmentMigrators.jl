using EnvironmentMigrators
using Test
using Pkg

function collect_files(path::AbstractString)
    flat_files = String[]
    for (root, dirs, files) in walkdir(path)
        for f in files
            push!(flat_files, joinpath(root,f))
        end
    end
    flat_files
end

@testset "EnvironmentMigrators.jl" begin
    Pkg.activate(mktempdir())
    Pkg.add("REPL")
    @test EnvironmentMigrators.list_shared_environments() isa Vector{String}
    @test EnvironmentMigrators.backup_current_environment() === nothing
    current_env = Base.active_project()
    current_dir = dirname(current_env)
    backup_dir = joinpath(current_dir, "backups")
    @test isfile(current_env)
    @test isdir(backup_dir)
    @test backup_dir |> readdir |> !isempty
    timestamp_dir = backup_dir |> readdir |> first |> x->joinpath(backup_dir, x)
    @test timestamp_dir |> readdir |> !isempty
    timetstamp_dir_contents = timestamp_dir |> readdir |> x->filter(s->endswith(s, "toml"), x)
    @test "Project.toml" in timetstamp_dir_contents
    @test "Manifest.toml" in timetstamp_dir_contents
    sleep(2)
    @test EnvironmentMigrators.migrate_selected_environment(Base.active_project()) === nothing
    sleep(2)
    t = mktempdir()
    @test EnvironmentMigrators.migrate_selected_environment(t; backup = true) === nothing
    t = mktempdir()
    @test EnvironmentMigrators.migrate_selected_environment(t; backup = false) === nothing
    t = mktempdir()
    touch(joinpath(t, "Project.toml"))
    touch(joinpath(t, "Manifest.toml"))
    @test EnvironmentMigrators.migrate_selected_environment(t; backup = true) === nothing
    t = mktempdir()
    touch(joinpath(t, "JuliaProject.toml"))
    touch(joinpath(t, "JuliaManifest.toml"))
    @test EnvironmentMigrators.migrate_selected_environment(t; backup = true) === nothing
    t = mktempdir()
    touch(joinpath(t, "JuliaProject.toml"))
    touch(joinpath(t, "JuliaManifest.toml"))
    Pkg.activate(t)
    @test EnvironmentMigrators.migrate_selected_environment(t; backup = true) === nothing
    backup_files = collect_files(joinpath(t, "backups"))
    @test backup_files |> x->filter(s->endswith(s, "JuliaProject.toml"), x) |> !isempty
    @test backup_files |> x->filter(s->endswith(s, "JuliaManifest.toml"), x) |> !isempty
end
