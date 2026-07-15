# storage.jl
# Demand file storage monitoring and cleanup utilities.

const DEMAND_DIRS = ["outputs/demands", "outputs/exp_demands", "outputs/sensitivity_demands"]

"""
    check_demand_storage(; warn_threshold_mb=100.0)

Check all demand output directories for existing files. Prints a warning with
file count and total size if any demand files are found. Called automatically
on module load.
"""
function check_demand_storage(; warn_threshold_mb::Float64=100.0)
    total_files = 0
    total_bytes = 0
    dir_info = Tuple{String, Int, Int}[]

    for dir in DEMAND_DIRS
        isdir(dir) || continue
        files = filter(f -> endswith(f, ".jld2") || endswith(f, ".json"), readdir(dir))
        isempty(files) && continue
        n = length(files)
        sz = sum(filesize(joinpath(dir, f)) for f in files)
        push!(dir_info, (dir, n, sz))
        total_files += n
        total_bytes += sz
    end

    total_files == 0 && return nothing

    total_mb = round(total_bytes / 1e6; digits=1)

    msg = "Demand files exist ($total_files files, $(total_mb) MB total):"
    for (dir, n, sz) in dir_info
        msg *= "\n  $dir — $n files ($(round(sz / 1e6; digits=1)) MB)"
    end
    msg *= "\n  Run clear_demands() to remove all, or clear_demands(\"$((dir_info[1][1]))\") for one directory."

    if total_mb > warn_threshold_mb
        @warn msg
    else
        @info msg
    end

    return (files=total_files, size_mb=total_mb)
end

"""
    clear_demands(dir=nothing; force=false)

Delete demand files (.jld2, .json) from output directories.

- `clear_demands()` — clears all demand directories (with confirmation)
- `clear_demands("outputs/demands")` — clears a specific directory
- `clear_demands(; force=true)` — skip confirmation prompt
"""
function clear_demands(dir::Union{String, Nothing}=nothing; force::Bool=false)
    dirs = dir === nothing ? DEMAND_DIRS : [dir]

    total = 0
    for d in dirs
        isdir(d) || continue
        files = filter(f -> endswith(f, ".jld2") || endswith(f, ".json"), readdir(d))
        total += length(files)
    end

    total == 0 && (@info "No demand files to clear."; return 0)

    if !force
        println("This will delete $total demand files. Continue? (y/n): ")
        choice = strip(readline())
        choice in ("y", "Y") || (@info "Aborted."; return 0)
    end

    deleted = 0
    for d in dirs
        isdir(d) || continue
        files = filter(f -> endswith(f, ".jld2") || endswith(f, ".json"), readdir(d))
        for f in files
            rm(joinpath(d, f))
            deleted += 1
        end
    end

    @info "Cleared $deleted demand files."
    return deleted
end

"""
    demand_storage_summary() → NamedTuple

Returns a summary of demand file storage across all output directories.
"""
function demand_storage_summary()
    info = Dict{String, NamedTuple{(:files, :size_mb), Tuple{Int, Float64}}}()
    for dir in DEMAND_DIRS
        isdir(dir) || continue
        files = filter(f -> endswith(f, ".jld2") || endswith(f, ".json"), readdir(dir))
        isempty(files) && continue
        sz = sum(filesize(joinpath(dir, f)) for f in files)
        info[dir] = (files=length(files), size_mb=round(sz / 1e6; digits=1))
    end
    return info
end
