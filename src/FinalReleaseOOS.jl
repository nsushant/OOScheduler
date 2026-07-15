module FinalReleaseOOS

# ── Dependencies ─────────────────────────────────────────────────────────────
using LinearAlgebra
using HDF5
using JLD2
using ProgressMeter
using Distributions
using StatsBase
using StatsBase: Weights
using Random
using Dates
using JSON3
using CairoMakie
using NLsolve
using VegaLite
using DataFrames
using Printf
using Base.Threads

# ── Sim Layer ────────────────────────────────────────────────────────────────
include("sim/orbital_mechanics.jl")
include("sim/propagator.jl")

# ── Cost / Transfer ──────────────────────────────────────────────────────────
include("cost/lu_transfer.jl")
include("cost/ht_transfer.jl")
include("cost/cost_functions.jl")
include("cost/gen_cost_table.jl")
include("cost/adaptive_grid.jl")

# ── Demand Generator ─────────────────────────────────────────────────────────
include("demands/generate_demands.jl")

# ── Solver (MDLS) ────────────────────────────────────────────────────────────
include("solver/sol_utils.jl")
include("solver/algoMDLS.jl")

# ── Plots ────────────────────────────────────────────────────────────────────
include("plots/gantt.jl")
include("plots/visualise.jl")
include("plots/gradients.jl")

# ── Storage Monitoring ───────────────────────────────────────────────────────
include("storage.jl")

# ── Exports ──────────────────────────────────────────────────────────────────

# Types
export OrbElem, Sat, Simulation, vehicle, Archive, AdaptiveGrid

# Simulation
export gen_simulation, gen_simulation_from_sats, load_sim

# Cost tables
export gen_cost_table, load_cost_table, build_min_tof_table
export LT_cost_calculation, HT_cost_calculation
export calculate_transfer_cost
export gen_adaptive_cost_table, load_adaptive_cost_table

# Demands
export generate_demands, load_demands, clear_demands
export check_demand_storage, demand_storage_summary

# Solver
export MDLS, make_init_schedule, save_schedule_json
export opt_times_combined, consolidate_demands, swap_cross_vehicle
export swap_intratour, create_vehicle, destroy_and_repair
export shaw_removal_repair, raan_walk_resequence, raan_phasing_timing
export build_min_dv_table, snap_cost, copy_schedule
export weibull_depreciate

# Plots
export plotdvtable, plotdemands, plot_pareto, plot_comparison
export plot_spider_comparison, plot_schedule_gantt, plot_schedule_comparison
export plot_gradient, plot_refinement_grid, plot_refinement_comparison
export plot_grid_comparison

# Constants (useful for scripts)
export INFEASIBLE_LEG_COST, COST_TABLE_PERIOD, REFUEL_TIME

# ── Module init: check for leftover demand files ─────────────────────────────
function __init__()
    check_demand_storage()
end

end # module FinalReleaseOOS
