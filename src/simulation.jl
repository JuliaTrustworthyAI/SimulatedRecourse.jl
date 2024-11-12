"""
Hides the parameters of an experiment behind a single struct.
"""
struct SimulationExperiment
    decision_path::String # the dataset for decision-making
    graph_path::String # the process graph
    test_path::String # the dataset for investigations

    train_path::Union{String,Nothing} # the dataset for training an investigation model
    model_path::Union{String,Nothing} # the pre-trained investigation model
    config_path::Union{String,Nothing} # the configuration of the model

    total_agents::Int # the number of agents in a simulation
    target::Int # the positive label (i.e., low-risk score)
    investigation_freq::Int # the maximum allowable frequency of investigations
    p_random_nomination::Float64 # the probability of random nomination
    process_data::Function # the function to process train and test data
    seed::Int # the seed for the pseudo-random number generator

    model::Symbol
    generator::Symbol
end

"""
    load_experiment(filename::String)

Load a configuration of the simulation experiment and create the initialization object.
Optional fields are set to default values unless explicitly specified in the config. 

Required:
    - filename (String): path to the `.json` file storing the configuration of the simulation experiment.
"""
function load_experiment(filename::String)
    config = JSON.parsefile(filename)
    decision_path = if "decision_path" in keys(config) config["decision_path"] else "data/decision_data.csv" end
    graph_path = if "graph_path" in keys(config) config["graph_path"] else "data/process_graph.txt" end
    test_path = config["test_path"]

    train_path = if "train_path" in keys(config) config["train_path"] else nothing end
    model_path = if "model_path" in keys(config) config["model_path"] else nothing end
    config_path = if "config_path" in keys(config) config["config_path"] else nothing end
    @assert typeof(model_path) == typeof(config_path)

    max_agents = nrow(CSV.read(decision_path, DataFrame))
    total_agents = if "total_agents" in keys(config) config["total_agents"] else max_agents end
    @assert total_agents <= max_agents
    target = if "target" in keys(config) config["target"] else 0 end
    investigation_freq = if "investigation_freq" in keys(config) config["investigation_freq"] else 1 end
    p_random_nomination = if "p_random_nomination" in keys(config) config["p_random_nomination"] else 0.175 end
    process_data = if occursin("rotterdam", test_path) get_rotterdam_data else get_synthetic_data end
    seed = if "seed" in keys(config) config["seed"] else 42 end

    model = if "model" in keys(config) Symbol(config["model"]) else :NeuroTreeModel end
    generator = if "generator" in keys(config) Symbol(config["generator"]) else :wachter end

    return SimulationExperiment(decision_path, graph_path, test_path, train_path, model_path, config_path, total_agents,
                                target, investigation_freq, p_random_nomination, process_data, seed, model, generator)
end

"""
    function initialize(experiment::SimulationExperiment; η::Float64, opt::DataType,
                        λ::Float64, decision_threshold::Float64, max_iter::Int)

Initializes the agent-based simulation.
Number of agents is influenced by `total_agents`; the first `total_agents` from the dataset are instantiated.

Requires:
    - `experiment` (SimulationExperiment): the initialization object describing the configuration of an experiment.

Optional:
    - `η` (Float64): the learning rate for counterfactual explanation optimizer.
    - `opt` (DataType): the optimizer for counterfactual explanation search.
    - `λ` (Float64): the strength of the penalty term of the generator
    - `decision_threshold` (Float64): convergence parameter for counterfactual explanation search.
    - `max_iter` (Float64): maximum number of iterations in counterfactual explanation search.
"""
function initialize(experiment::SimulationExperiment; seed::Int=42, η::Float64=1.0, opt::DataType=Flux.Descent,
                    λ::Float64=0.5, decision_threshold::Float64=0.95, max_iter::Int=1000)

    # Prepare the graph space to be populated by agents
    graph, stages, stage_names = Process.initialize_graph(experiment.graph_path)
    graph_space = GraphSpace(graph)

    properties = Dict(
        :stages => stages,
        :stage_names => stage_names,
        :model => nothing,
        :target => experiment.target,
        :investigation_freq => experiment.investigation_freq,
        :p_random_nomination => experiment.p_random_nomination,
        :rotterdam => false
    )

    # Simulations on Rotterdam need to be marked to change some additional features
    test_path = experiment.test_path
    if endswith(test_path, "investigation_test.csv")
        properties[:rotterdam] = true
    end

    # Certain simulations may be executed without an investigation model, e.g., only random nominations 
    model_path = experiment.model_path
    if !isnothing(model_path)
        config_path = experiment.config_path
        process_data = experiment.process_data
        # If the file exists, we load the pretrained model
        if isfile(model_path)
            # Load the pre-trained model that will be used to nominate for investigation
            BSON.@load model_path model

        # Otherwise, we train a new model
        else
            model = train_model(experiment.train_path, config_path, model_path, process_data, experiment.model)
            evaluate_model(test_path, config_path, model_path, process_data)
        end

        X, y, feature_names = process_data(test_path)
        categorical, continuous, domain, mutability, difficulty = Process.parse_config(config_path)

        # Create the CounterfactualData object that will be used to explore recourse options
        counterfactual_data = CounterfactualData(
            Tables.table(Tables.matrix(X)), y;
            features_categorical=categorical,
            features_continuous=continuous,
            domain=domain,
            mutability=mutability
        )

        # Store simulation-level properties including the stages and their names,
        # the investigation model, the counterfactual data object, and the positive (low-risk) target
        properties[:model] = model
        properties[:feature_names] = feature_names
        properties[:counterfactual_data] = counterfactual_data
        properties[:difficulty] = difficulty
    end
    
    # Allow for reproducible simulations
    rng = Xoshiro(seed)

    # TODO: Find a better way to instantiate the generator 
    # Set up the counterfactual generator
    properties[:generator] = generator_catalogue[experiment.generator](; opt=opt(η), λ=λ)
    properties[:convergence] = CounterfactualExplanations.Convergence.DecisionThresholdConvergence(;
        decision_threshold=decision_threshold, max_iter=max_iter
    )

    # Instantiate the ABM object populated by `Customer` agents in the `graph_space`.
    # Actions of agents are coordinated through the `welfare_step!` method
    sim = StandardABM(
        Customer,
        graph_space;
        (agent_step!)=agent_step!,
        properties=properties,
        rng=rng,
        container=Vector
    )

    # Load the dataset of agents with custom features used for making decisions about eligibility.
    # Then, keep first `total_agents` entries to use in the simulation.
    decision_data = CSV.read(experiment.decision_path, DataFrame)
    sampled_data = decision_data[StatsBase.sample(
        abmrng(sim), axes(decision_data, 1), experiment.total_agents; replace = false, ordered = true), :]

    for (index, features) in enumerate(eachrow(sampled_data))
        # All agents start in the Idle state, i.e., outside of the decision-making process.
        add_agent!(stage_names["Idle"], sim; features=features)
        sim[index].properties[:recommendation] = nothing
        sim[index].properties[:cycles_since_investigation] = 0
        sim[index].properties[:total_investigations] = 0
        sim[index].properties[:model_investigations] = 0

    end
    
    Logging.@logmsg Logging.LogLevel(0) "Model: $(typeof(sim.model))"
    # Return the runnable simulation object.
    return sim
end

"""
    welfare_step!(agent::Customer, sim::ABM)

Executes a step of the simulation for the specific `agent`.
This function is used internally by `run!(⋅)` of Agents.jl.

Required:
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
"""
function agent_step!(agent::Customer, sim::ABM)
    # Implementation of `update_agent!` depends on the specific case.
    # It may, e.g., update the values of the features of the `agent` in a particular cycle.
    Case.update_agent!(agent, sim)

    # Process the `agent` based on the stage where it is currently located. 
    stage = sim.stages[agent.pos]
    Logging.@logmsg Logging.LogLevel(-5) "Agent $(agent.id) in stage $(sim.stage_names(agent.pos))."
    Process.process(stage, agent, sim)
end

"""
    run_sim(config::String; seed::Int, steps::Int, visualize::Bool, log_level::Int)

Runs a single simulation model for `steps` number of steps.

Required:
    - `config` (String): path to the `.json` file storing the configuration of the simulation experiment.

Optional:
    - `seed` (Int): seed for the pseudorandom number generator to ensure reproducible models.
    - `steps` (Int): number of individual updates of all agents in the model.
    - `visualize` (Bool): if true, the simulation model creates a plot that represents the flows of agents.
    - `log_level` (Int): verbosity of logging, lower numbers print more messages.
"""
function run_sim(config::String="data/rotterdam/experiment_config_26.json"; seed::Int=42,
                 steps::Int=100, visualize::Bool=false, log_level::Int=0)
    logger = ConsoleLogger(stdout, Logging.LogLevel(log_level))

    adata, mdata, duration, agent_distribution, eligible = nothing, nothing, nothing, nothing, nothing

    with_logger(logger) do
        # Run the simulation on the Rotterdam data
        experiment = load_experiment(config)
        welfare = initialize(experiment, seed=seed)
        start_time = now()
        Logging.@logmsg Logging.LogLevel(0) "Simulation started at $start_time."

        if visualize
            abmobs = ABMObservable(welfare)
            agent_positions(model) = [length(ids_in_position(pos, model)) for pos in positions(model)]
            nums = lift(agent_positions, abmobs.model)
            title = "Number of agents per stage"

            fig = Figure(size = (600, 400))
            xticks = (1:8, ["Idle", "Application", "Decision", "PostDecision", "ReceivingBenefits",
                            "Investigation", "PostInvestigation", "Recourse"])
            ax = Axis(fig[1, 1]; title, xlabel = "Stage", ylabel = "Population", xticks=xticks, xticklabelrotation=45)
            barplot!(ax, nums; strokecolor = :black, strokewidth = 1)

            record(fig, "outputs/welfare.mp4"; framerate = 24) do io
                for j in range(1, steps)
                    recordframe!(io)
                    Agents.step!(abmobs, 1)
                end
                recordframe!(io)
            end
        else
            to_collect = [:properties]
            adata, mdata = run!(welfare, steps, adata = to_collect)
        end

        agent_distribution = [length(ids_in_position(pos, welfare)) for pos in positions(welfare)]

        eligible = 0
        for agent in allagents(welfare)
            status, _ = Case.calculate_assistance(agent)
            if status == :A
                eligible += 1
            end
        end

        Logging.@logmsg Logging.LogLevel(0) "Distribution of customers over stages: $(agent_distribution)."

        end_time = now()
        duration = (end_time - start_time)
        Logging.@logmsg Logging.LogLevel(0) "Simulation completed at $end_time after $duration."
    end
    return adata, mdata, duration, agent_distribution, eligible
end