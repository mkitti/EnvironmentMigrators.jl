using EnvironmentMigrators
using Test
using Pkg

@testset "EnvironmentMigrators.jl" begin
    Pkg.activate(mktempdir())
    Pkg.add("REPL")
    @test EnvironmentMigrators.list_shared_environments() isa Vector{String}
    @test EnvironmentMigrators.backup_current_environment() === nothing
    sleep(2)
    @test EnvironmentMigrators.migrate_selected_environment(Base.active_project()) === nothing
    sleep(2)
    @test EnvironmentMigrators.migrate_selected_environment(mktempdir(); backup = true) === nothing
    @test EnvironmentMigrators.migrate_selected_environment(mktempdir(); backup = false) === nothing
end
