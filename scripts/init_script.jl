# init_script.jl
# Setup: generates simulation, cost table, demands, and visualisations.
# Run: julia --project=.. init_script.jl

using FinalReleaseOOS

# ── Constellation ─────────────────────────────────────────────────────────────
constellation_params = Dict(
    "type"           => "delta_walker",
    "num_planes"     => 10.0,
    "num_satellites"  => 300,
    "phasing"        => 1.0,
    "inclination"    => 53.0,
    "altitude"       => 550.0,
)

depot_params = Dict(
    "type"        => "depot",
    "altitude"    => 600.0,
    "inclination" => 53.0,
    "RAAN"        => 0.0,
    "e"           => 0.001,
)

sim_params = Dict(
    "J2"    => true,
    "dt"    => 60,
    "t_end" => 5.0 * 365.0 * 24.0 * 60.0 * 60.0,
)

# ── Propagate ─────────────────────────────────────────────────────────────────
simulation = gen_simulation([constellation_params, depot_params], sim_params)

# ── Cost table ────────────────────────────────────────────────────────────────
cost_table = gen_cost_table(simulation)

# ── Demands ───────────────────────────────────────────────────────────────────
demand_params = Dict(
    "num_demands"    => 100,
    "num_satellites"  => 100,
    "type"           => "random",
    "seed"           => 42,
    "disttype"       => "normal",
    "deltaV_dist"    => 10000,
    "time_dist"      => [10, 365],
    "service_times"  => [1.0, 5.0],
)

demands = generate_demands(simulation, demand_params)

# ── Visualisation ─────────────────────────────────────────────────────────────
depot_name = first(filter(n -> startswith(n, "depot"), simulation.names))
sat_name   = first(filter(n -> startswith(n, "sat"),   simulation.names))

fig1 = plotdvtable(depot_name, sat_name, cost_table, simulation)
save("outputs/dv_depot_to_sat.png", fig1)

fig2 = plotdemands(demands, cost_table, simulation)
save("outputs/demands.png", fig2)
