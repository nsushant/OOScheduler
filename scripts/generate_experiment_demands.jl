# generate_experiment_demands.jl
# Generates demand JLD2 files and greedy JSON seeds for 4 scenarios × N_TRIALS.
# Run: julia --project=.. generate_experiment_demands.jl

using FinalReleaseOOS
using JLD2, JSON3, Dates, Random

const N_DEMANDS   = 200
const N_TRIALS    = 5
const OUT_DIR     = "outputs/exp_demands"

const V1_VALUE    = 864_150.0
const V2_VALUE    = 2_280_000.0
const DEFAULT_ASSET_VALUE = V1_VALUE
const V2_FRACTION = 0.30
const SIM_START_DATE = Date(2024, 1, 1)

const LAUNCH_DATES_PATH = "outputs/sat_launch_dates.json"
const _SAT_LAUNCH_DATES = isfile(LAUNCH_DATES_PATH) ?
    JSON3.read(read(LAUNCH_DATES_PATH), Dict{String,String}) : Dict{String,String}()
isempty(_SAT_LAUNCH_DATES) &&
    @warn "sat_launch_dates.json not found — using fallback age of 2.0 years"

const MIXED_VALUES_PATH = "outputs/mixed_sat_values.json"
const _MIXED_SAT_VALUES = isfile(MIXED_VALUES_PATH) ?
    JSON3.read(read(MIXED_VALUES_PATH), Dict{String,Float64}) : Dict{String,Float64}()

function depreciated_sat_values(sim, seed)
    rng = MersenneTwister(seed)
    sat_names = filter(n -> startswith(n, "sat"), sim.names)
    Dict{String,Float64}(
        n => if haskey(_MIXED_SAT_VALUES, n)
                _MIXED_SAT_VALUES[n]
             else
                base = rand(rng) < V2_FRACTION ? V2_VALUE : V1_VALUE
                ld   = get(_SAT_LAUNCH_DATES, n, nothing)
                age  = isnothing(ld) ? 2.0 :
                       max(0.0, Dates.value(SIM_START_DATE - Date(ld)) / 365.25)
                weibull_depreciate(base, age)
             end
        for n in sat_names
    )
end

const INSTANCES = [
    (name   = "tight_normal",
     params = Dict("num_demands" => N_DEMANDS, "type" => "random",
                   "disttype" => "normal", "deltaV_dist" => 8000.0,
                   "time_dist" => [10.0, 100.0], "service_times" => [1.0, 3.0],
                   "default_asset_value" => DEFAULT_ASSET_VALUE)),
    (name   = "loose_uniform",
     params = Dict("num_demands" => N_DEMANDS, "type" => "random",
                   "disttype" => "uniform", "deltaV_dist" => 8000.0,
                   "time_dist" => [50.0, 365.0], "service_times" => [1.0, 5.0],
                   "default_asset_value" => DEFAULT_ASSET_VALUE)),
    (name   = "tight_low_dv",
     params = Dict("num_demands" => N_DEMANDS, "type" => "random",
                   "disttype" => "normal", "deltaV_dist" => 5000.0,
                   "time_dist" => [10.0, 200.0], "service_times" => [1.0, 4.0],
                   "default_asset_value" => DEFAULT_ASSET_VALUE)),
    (name   = "loose_high_dv",
     params = Dict("num_demands" => N_DEMANDS, "type" => "random",
                   "disttype" => "uniform", "deltaV_dist" => 12000.0,
                   "time_dist" => [100.0, 365.0], "service_times" => [1.0, 5.0],
                   "default_asset_value" => DEFAULT_ASSET_VALUE)),
]

mkpath(OUT_DIR)
sim = load_sim()

@info "Loading cost table …"
CostTable = load("outputs/cost_table.jld2", "CostTable")
@info "Cost table loaded" n_entries=length(CostTable)

@info "Building min-TOF table …"
MinTOFTable = build_min_tof_table()
@info "Min-TOF table ready" n_entries=length(MinTOFTable)

for inst in INSTANCES
    @info "─── Scenario: $(inst.name) ───"
    for trial in 1:N_TRIALS
        seed      = trial * 137 + Int(hash(inst.name) % 1000)
        sat_values_trial = depreciated_sat_values(sim, seed)
        params    = merge(inst.params, Dict("seed" => seed, "sat_values" => sat_values_trial))
        trial_str = lpad(trial, 2, '0')

        @info "  Generating demands" trial=trial seed=seed
        demands = generate_demands(sim, params; cost_table=CostTable)

        dem_path = joinpath(OUT_DIR, "$(inst.name)_$(trial_str).jld2")
        @save dem_path demands
        @info "  Saved demands" path=dem_path n=length(demands["UIDs"])

        @info "  Building greedy schedule …"
        init_sol, init_unas = make_init_schedule(demands, sim;
            nvehicles=20, min_tof_table=MinTOFTable)
        greedy_path = joinpath(OUT_DIR, "$(inst.name)_$(trial_str)_greedy.json")
        save_schedule_json(init_sol, init_unas, greedy_path)
        @info "  Saved greedy" path=greedy_path n_vehicles=length(init_sol)
    end
end

@info "Done. Generated $(length(INSTANCES) * N_TRIALS) demand+greedy pairs." OUT_DIR
