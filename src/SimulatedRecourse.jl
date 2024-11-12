"""
Super-module that applies the Case to the Process framework.
"""
module SimulatedRecourse

    using Agents
    using Agents.Graphs
    using Bijections
    using BSON
    using CairoMakie
    using CounterfactualExplanations
    using CSV
    using DataFrames
    using Dates
    using Flux
    using JSON
    using Logging
    using MLJ
    using NeuroTreeModels
    using Parameters
    using Random
    using Statistics
    using StatsBase
    using Tables

    # Declare methods stubs so they are in scope for Process where they are used
    function idle_logic end
    function application_logic end
    function decision_logic end
    function postdecision_logic end
    function receiving_benefits_logic end
    function investigation_logic end
    function postinvestigation_logic end
    function recourse_logic end

    # Load definitions from Process that are necessary for case
    include("./process/Process.jl")
    using .Process: Customer, Idle, Application, Decision, PostDecision
    using .Process: ReceivingBenefits, Investigation, PostInvestigation, Recourse, process
    using .Process: select_transition, parse_config
    # Export definitions from Process to be in scope for case
    export Customer, Idle, Application, Decision, PostDecision
    export ReceivingBenefits, Investigation, PostInvestigation, Recourse, process
    export select_transition, parse_config

    # Load overriden definitions of function stubs from Case
    include("./case/Case.jl")
    import .Case: idle_logic, application_logic, decision_logic, postdecision_logic
    import .Case: receiving_benefits_logic, investigation_logic, postinvestigation_logic, recourse_logic
    import .Case: get_rotterdam_data, get_synthetic_data

    # Load additional functions
    include("./scripts/models.jl")

    # Load driver code and expose a run method
    include("simulation.jl")

    # Run a simulation study
    function run_experiment(config::String="data/rotterdam/experiment_config_model.json";
                            n_repetitions::Int=100, steps::Int=(24 + 12 * 20), write_files::Bool=true)
        results = Dict(
            :agents_all_investigations => Vector{Int}(),
            :agents_model_investigations => Vector{Int}(),
            :total_investigations => Vector{Int}(),
            :model_investigations => Vector{Int}(),
            :mean_all_investigations => Vector{Float64}(),
            :mean_model_investigations => Vector{Float64}(),
            :computation_time => Vector{Int}(),
            :agent_distribution => Vector{Vector{Int}}(),
            :ground_truth_eligible => Vector{Int}()
        )

        filename = split(config, "_config_")[2]
        for i in 1:n_repetitions
            adata, _, duration, agent_distribution, eligible = run_sim(config, seed=i, steps=steps, visualize=false)
            # Find property entries for all agents at the last time step of the investigation
            props = adata[adata.time .== steps, :][!, :properties]
            push!(results[:ground_truth_eligible], eligible)

            # Find all agents who have experienced at least one investigation
            total_nonzero = findall(!iszero, [d[:total_investigations] for d in props])
            model_nonzero = findall(!iszero, [d[:model_investigations] for d in props])
            
            # Find the total number of agents who experienced at least one investigation
            agents_all_investigations = length(total_nonzero)
            push!(results[:agents_all_investigations], agents_all_investigations)

            # Find the total number of agents who experienced at least one model investigation
            agents_model_investigations = length(model_nonzero)
            push!(results[:agents_model_investigations], agents_model_investigations)
            
            # Find the total number of investigations
            total_investigations = sum([d[:total_investigations] for d in props][total_nonzero])
            push!(results[:total_investigations], total_investigations)

            # Find the number of model investigations
            model_investigations = sum([d[:model_investigations] for d in props][model_nonzero])
            push!(results[:model_investigations], model_investigations)
            
            # Find the mean number of investigations
            mean_all_investigations = mean([d[:total_investigations] for d in props][total_nonzero])
            push!(results[:mean_all_investigations], mean_all_investigations)

            # Find the mean number of model investigations
            mean_model_investigations = mean([d[:model_investigations] for d in props][model_nonzero])
            push!(results[:mean_model_investigations], mean_model_investigations)
            
            push!(results[:computation_time], Dates.value(duration))
            push!(results[:agent_distribution], agent_distribution)

            if write_files
                open("outputs/$filename", "w") do outfile
                    JSON.print(outfile, results)
                end
            end
        end

        parsed_results = Dict(
            :agents_all_investigations => 0.0,
            :agents_model_investigations => 0.0,
            :total_investigations => 0.0,
            :model_investigations => 0.0,
            :mean_all_investigations => 0.0,
            :mean_model_investigations => 0.0,
            :computation_time => 0.0,
            :agent_distribution => Vector{Float64}(),
            :ground_truth_eligible => 0.0
        )
        for k in keys(results)
            parsed_results[k] = mean(results[k])
            println("$k --- $(mean(results[k]))")
        end

        if write_files
            open("outputs/averages_$(filename)", "w") do outfile
                JSON.print(outfile, parsed_results)
            end
        end
        return results
    end

    export run_experiment
    export train_model, evaluate_model
end
