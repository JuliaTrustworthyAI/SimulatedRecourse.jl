"""
    dispatch_stage(stage::String, data::StageData)

For readability, the stages are accessed by their names in the simulation,
but their underlying representation in the process graph relies on integer IDs.

Function `dispatch_stage` converts between the String name of a state and its object.

Requires:
    - stage (String): the name of one of the stages defined for the simulation.
    - data (StageData): the metadata of the `stage`, including its transitions configuration.
"""
function dispatch_stage(stage::String, data::StageData)
    return Dict("Idle" => Idle,
                "Application" => Application,
                "Decision" => Decision,
                "PostDecision" => PostDecision,
                "ReceivingBenefits" => ReceivingBenefits,
                "Investigation" => Investigation,
                "PostInvestigation" => PostInvestigation,
                "Recourse" => Recourse,
            )[stage](data)
end

"""
    select_transition(next::Dict{Int, Float64}, ban_list::Vector{Int})

Default values for all transitions are provided by the input graph,
but depending on the circumstances some stages may become inaccessible to agents.

Function `select_transition` probabilistically selects the next transition for an agent.

Requires:
    - `next` (Dict{Int, Float64}): a dictionary of possible next stages with corresponding probabilities.
    - `ban_list` (Vector{Int}): a vector of stages that should not be accessible for the agent as next stage.
    - `rng` (Random.AbstractRNG): a pseudo-random number generator object.
"""
function select_transition(next::Dict{Int, Float64}, ban_list::Vector{Int} = Vector{Int}(); rng=Xoshiro(42))
    # Ensure that there is at least one stage where the agent will be able to move
    @assert length(next) > length(ban_list)

    # Filter out the entries from `next` based on the entries in `ban_list`
    filtered_next = filter(entry -> entry[1] ∉ ban_list, next)

    # Get a list of accessible next states
    choices = collect(keys(filtered_next))
    # Get a list of normalized probabilities for next stages (may not sum to 1 if `ban_list` was non-empty)
    probas = collect(values(filtered_next))
    probas /= sum(probas)

    # Randomly select the next stage for the agent weighted by `probas`
    return sample(rng, choices, StatsBase.pweights(probas))
end

"""
Declare that function `update_agent!` ought to be implemented in Case.
"""
function update_agent! end