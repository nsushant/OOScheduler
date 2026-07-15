# FinalReleaseOOS

On-orbit servicing (OOS) mission planning library for scheduling satellite service requests subject to orbital mechanics, transfer costs, and vehicle constraints.

## Installation

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## Quick Start

```julia
using FinalReleaseOOS

# 1. Define constellation + depot
constellation = Dict(
    "type"           => "delta_walker",
    "num_planes"     => 10.0,
    "num_satellites"  => 300,
    "phasing"        => 1.0,
    "inclination"    => 53.0,
    "altitude"       => 550.0,
)

depot = Dict(
    "type"        => "depot",
    "altitude"    => 600.0,
    "inclination" => 53.0,
    "RAAN"        => 0.0,
    "e"           => 0.001,
)

sim_params = Dict("J2" => true, "dt" => 60, "t_end" => 5.0 * 365.25 * 86400.0)

# 2. Propagate orbits (writes outputs/simulation.h5)
sim = gen_simulation([constellation, depot], sim_params)

# 3. Build pairwise transfer cost table (writes outputs/cost_table.jld2)
cost_table = gen_cost_table(sim)

# 4. Generate service demands
demands = generate_demands(sim, Dict(
    "num_demands"   => 100,
    "deltaV_dist"   => 10000,
    "time_dist"     => [10, 365],
    "service_times" => [1.0, 5.0],
    "disttype"      => "normal",
    "seed"          => 42,
))

# 5. Solve with MDLS
mintof  = build_min_tof_table()
min_dv  = build_min_dv_table(cost_table, maximum(k[1] for k in keys(cost_table)))
archive = MDLS(1000, demands, sim, cost_table, mintof, min_dv)
```

## Storage Monitoring

Demand files accumulate in `outputs/` over repeated runs. The library warns automatically on load:

```
┌ Info: Demand files exist (45 files, 230.5 MB total):
│   outputs/demands — 10 files (52.1 MB)
│   outputs/exp_demands — 35 files (178.4 MB)
└   Run clear_demands() to remove all, or clear_demands("outputs/demands") for one directory.
```

```julia
clear_demands()                      # clear all demand dirs (with confirmation)
clear_demands("outputs/demands")     # clear one directory
clear_demands(; force=true)          # skip confirmation
demand_storage_summary()             # inspect without clearing
```

## Visualisation

```julia
# ΔV heatmap for a specific transfer pair
fig = plotdvtable("depot_1", "sat_0", cost_table, sim)

# Demand scatter plot
fig = plotdemands(demands, cost_table, sim)

# Pareto front from MDLS
fig = plot_pareto(archive)

# Gantt chart (.html for interactive, .png for static)
init_sol, _ = make_init_schedule(demands, sim)
plot_schedule_gantt(init_sol; save_to="outputs/schedule.html")
```

## Scripts

Run from the `scripts/` directory:

```bash
# Full pipeline: propagate → cost table → demands → plots
julia --project=.. scripts/init_script.jl

# Generate experiment demands (4 scenarios × 5 trials)
julia --project=.. scripts/generate_experiment_demands.jl

# Generate sensitivity analysis demands
julia --project=.. scripts/generate_sensitivity_demands.jl [se_name ...]

# Run MDLS on a specific trial
julia --project=.. -t auto scripts/run_mdls_trial.jl tight_normal 1
```

## Testing

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Project Structure

```
FinalReleaseOOS/
├── Project.toml              # Package manifest + dependencies
├── LICENSE                   # MIT
├── src/
│   ├── FinalReleaseOOS.jl    # Module entry point (all imports + exports)
│   ├── storage.jl            # Demand file monitoring + cleanup
│   ├── sim/
│   │   ├── orbital_mechanics.jl   # Two-body + J2, RK4, Walker Delta
│   │   └── propagator.jl         # Orbit propagation → HDF5
│   ├── cost/
│   │   ├── lu_transfer.jl        # Low-thrust (Lu analytical model)
│   │   ├── ht_transfer.jl        # High-thrust (Izzo Lambert solver)
│   │   ├── cost_functions.jl     # LT/HT wrappers reading from HDF5
│   │   ├── gen_cost_table.jl     # Pairwise cost table with plane grouping
│   │   └── adaptive_grid.jl     # Adaptive mesh refinement for cost table
│   ├── demands/
│   │   └── generate_demands.jl   # Service demand generation
│   ├── solver/
│   │   ├── sol_utils.jl          # Schedule structs, greedy construction, archive
│   │   └── algoMDLS.jl           # MDLS multi-objective optimizer
│   └── plots/
│       ├── visualise.jl          # Heatmaps, scatter, Pareto front, spider
│       ├── gantt.jl              # Gantt charts (CairoMakie + VegaLite)
│       └── gradients.jl          # ΔV gradient visualisation
├── scripts/                  # Executable pipelines
└── test/
    └── runtests.jl
```

## Key Types

| Type | Description |
|------|-------------|
| `Simulation` | Propagated constellation (positions, orbital elements, HDF5 reference) |
| `vehicle` | Single servicer route (visited UIDs, satellites, timing, costs) |
| `Archive` | Pareto front of solutions (octree-accelerated dominance checking) |
| `AdaptiveGrid` | Adaptively refined cost table for high-gradient regions |

## License

MIT
