"""
    initialize_graph(filename::String)

Initialize a graph to be used in the GraphSpace of the simulation,
as well as a corresponding vector of SimulationStages that allows to configure the process.

The data file is expected to follow the format:

n       # a single number of nodes in the decision-making graph
a b c   # multiple lines representing the edges of a graph
d e f   # in the format: "from" "to" "probability of transition"
k L     # multiple lines representing the types of each node
m N     # in the format: "id" "type"

Required:
    - `filename` (String): path to the `.txt` file storing the process graph.
"""
function initialize_graph(filename::String="data/process_graph.txt")
    file = open(filename, "r")
    # Initialize nodes in a graph based on the number on the first line
    n_nodes = parse(Int64, readline(file))
    graph = SimpleDiGraph(n_nodes)
    # Initialize a vector to store StageData for all nodes
    stage_data = [StageData(Vector{Int64}(), Dict{Int64, Float64}()) for _ in 1:n_nodes] 
    stages = Vector{SimulationStage}(undef, n_nodes)
    # Initialize a dictionary to access nodes by their name
    stage_names = Dict{String, Int64}()

    # Parse the rest of the file, line by line
    for l in eachline(file)
        line = split(l, " ")

        # Parse each line representing the two ends of a directed edge and the probability of taking that edge
        if length(line) == 3
            from = parse(Int64, line[1])
            to = parse(Int64, line[2])
            p = parse(Float64, line[3])

            # Add edges to the underlying graph structure
            add_edge!(graph, from, to)

            # Add edges to the vector of StageData
            # For each "from" node add the "next" node along with the probability
            stage_data[from].next[to] = p
            # For each "to" node add "previous" node
            append!(stage_data[to].previous, from)

        # Parse each line representing the type of a node
        elseif length(line) == 2
            node = parse(Int64, line[1])
            name = String(line[2])
            stages[node] = dispatch_stage(name, stage_data[node])
            stage_names[name] = node
        else
            println("Error parsing file ", filename)

        end

    end
    close(file)
    return graph, stages, Bijection(stage_names)
end

"""
    parse_inf(v::Union{Int, String})

Function to parse "Inf" values in the config file.

Required:
    - `v` (Union{Int, String}): the value of a domain constraint from the config file. 
"""
function parse_inf(v::Union{Int, String})
    # Value may be "Inf" which needs to be parsed as infinity
    if v isa String
        v = parse(Float64, v)
    end
    return v
end

"""
    exclude_features(base_list::Vector{Any}, exclude_list::Vector{Any})

Function to remove features given in `exclude_list` from the complete list of features in `base_list`.

Required:
    - `base_list` (Vector{Any}): a list of all features in the domain.
    - `exclude_list` (Vector{Any}): a list of features to be removed from consideration.
"""
function exclude_features(base_list::Vector{Any}, exclude_list::Vector{Any})
    parsed_features = []
    for feature in base_list
        # Vector may include a list with a single feature or a list of multiple OHE features
        # In any case, we delete the complete list
        if length(intersect(feature, exclude_list)) == 0
            push!(parsed_features, feature)
        end
    end
    return parsed_features
end

"""
    parse_config(filename::String)

Parse the config file for the training of models and the generation of counterfactuals.

Required:
    - filename (String): path to the `.json` file storing the configuration of the model.
"""
function parse_config(filename::String="data/rotterdam/investigation_config.json")
    config = JSON.parsefile(filename)
    excluded_features = config["excluded_features"]

    # Get a list of all categorical features, except for ones excluded from analysis
    categorical_features = convert(Vector{Vector{Int64}}, exclude_features(config["categorical_features"], excluded_features))
    # Get a list of all continuous features, except for ones excluded from analysis
    continuous_features = convert(Vector{Int64}, exclude_features(config["continuous_features"], excluded_features))

    # Parse mutability constraints to tuples and skip excluded indices
    domain_constraints = [(parse_inf(v[1]), parse_inf(v[2])) for v in config["domain_constraints"]]
    domain_constraints = domain_constraints[Not(excluded_features)]

    # Parse domain constraints to a list of symbols and skip excluded indices
    mutability_constraints = [Symbol(v) for v in config["mutability_constraints"]]
    mutability_constraints = mutability_constraints[Not(excluded_features)]

    difficulty = [v for v in config["difficulty_per_unit"]]

    return categorical_features, continuous_features, domain_constraints, mutability_constraints, difficulty
end