using Test
using FinalReleaseOOS
using LinearAlgebra: norm
using Random: MersenneTwister

@testset "FinalReleaseOOS" begin

    @testset "Orbital Mechanics" begin
        # Round-trip: OrbElem → ECI → OrbElem
        oe = OrbElem(6921.0, 0.001, deg2rad(53.0), deg2rad(45.0), 0.0, 0.0)
        r, v = FinalReleaseOOS.eci_from_oelem(oe)
        @test length(r) == 3
        @test length(v) == 3
        @test norm(r) ≈ oe.sma atol=10.0  # near-circular, r ≈ a

        oe2 = FinalReleaseOOS.oelem_from_rv(r, v)
        @test oe2.sma ≈ oe.sma atol=1.0
        @test oe2.inc ≈ oe.inc atol=0.01
    end

    @testset "Walker Delta" begin
        sats = FinalReleaseOOS.walker_delta(2, 10, 1, 6921.0, deg2rad(53.0))
        @test length(sats) == 10
        @test sats[1].name == "sat_0"
        @test sats[end].name == "sat_9"
    end

    @testset "Weibull Depreciation" begin
        @test weibull_depreciate(1_000_000.0, 0.0) == 1_000_000.0
        @test weibull_depreciate(1_000_000.0, 5.0) < 1_000_000.0
        @test weibull_depreciate(1_000_000.0, 5.0) > 0.0
        # Monotonically decreasing with age
        v1 = weibull_depreciate(1_000_000.0, 1.0)
        v2 = weibull_depreciate(1_000_000.0, 3.0)
        v3 = weibull_depreciate(1_000_000.0, 10.0)
        @test v1 > v2 > v3
    end

    @testset "Demand Distribution Sampler" begin
        rng = MersenneTwister(42)
        vals = FinalReleaseOOS.sample_from_dist("uniform", 10.0, 100.0, 50, rng)
        @test length(vals) == 50
        @test all(10.0 .<= vals .<= 100.0)

        rng2 = MersenneTwister(42)
        vals2 = FinalReleaseOOS.sample_from_dist("normal", 10.0, 100.0, 50, rng2)
        @test length(vals2) == 50
        @test all(10.0 .<= vals2 .<= 100.0)
    end

    @testset "Storage Monitoring" begin
        info = demand_storage_summary()
        @test info isa Dict
    end

    @testset "Lambert Solver" begin
        # Simple test: LEO to slightly different orbit
        r1 = [6921.0, 0.0, 0.0]
        v1 = [0.0, 7.67, 0.0]
        r2 = [0.0, 6921.0, 0.0]
        tof = 2700.0  # ~45 minutes

        sols = FinalReleaseOOS.lambert_solver(r1, r2, tof, 398600.4418, 0, 0)
        @test length(sols) >= 1
    end

    @testset "Phasing Cost" begin
        dv, Tp = FinalReleaseOOS.phasing(6921.0, 0.0, π)
        @test dv >= 0.0
        @test Tp >= 0.0
    end

end
