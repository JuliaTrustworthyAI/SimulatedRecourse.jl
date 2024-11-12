"""
    recourse_logic(current_stage::Recourse, agent::Customer, sim::ABM)

Execute the case-specific logic of the Recourse stage.
Here, the `agent` receives a recommendation on a way to reduce their risk score.

There are 2 situations when the agent may get here:
1. They are low risk (0) but have been predicted as high risk (1) -> recourse should lower predicted risk score.
2. They are high risk (1) and have been predicted as high risk (1) -> recourse should suggest a way to modify outcome.
If they would have been predicted as low risk, the investigation would not have started.

Required:
    - `current_stage` (Recourse): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function recourse_logic(current_stage::Recourse, agent::Customer, sim::ABM)
    if isnothing(sim.model)
        if agent.status == :A
            return move_agent!(agent, sim.stage_names["ReceivingBenefits"], sim)
        else
            return move_agent!(agent, sim.stage_names["Idle"], sim)
        end
    end

    agent.properties[:recommendation] = get_recommendation(agent, sim)
    num_features = count(!iszero, agent.properties[:recommendation])
    Logging.@logmsg Logging.LogLevel(-2) "Agent $(agent.id) received recommendation on $num_features features."
    
    # If the agent was rejected after reinvestigation, they move out of the social welfare process
    # They may begin to implement recourse in Idle
    if agent.status == :R
        return move_agent!(agent, sim.stage_names["Idle"], sim)
    
    # Otherwise the agent can freely move to any stage
    else
        return move_agent!(agent, sim.stage_names["ReceivingBenefits"], sim)
    end
end

"""
    get_recommendation!(agent::Customer, sim::ABM)

Helper function to generate domain-specific algorithmic recourse recommendations.
All data is effectively categorical (e.g., number of meetings or days) but with so many values that one-hot encoding is impractical.
Instead, we treat non-binary features as continuous, and round them away from zero in the recommendation issued to the agent.
This is not guaranteed to work unless the classifier is monotonous; however, agents cannot exert partial effort either way.
In practice there are only two (out of 12645) cases where the counterfactual needs to be re-generated once, so this works well.

Required:
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function get_recommendation(agent::Customer, sim::ABM)
    prediction = nothing
    # Get the agent's factual data and reshape it into a matrix as expected by the model
    factual = sim.counterfactual_data.X[:, agent.id]
    result = reshape(factual, size(factual)[1], 1)
    # Attempt to generate and round counterfactuals several times
    for i in range(1, 10)
        if !isnothing(prediction) && prediction == sim.target
            break
        else
            # Generate an explanation and access its counterfactual 
            explanation = generate_counterfactual(result, sim.target, sim.counterfactual_data,
                                                  sim.model, sim.generator, initialization=:identity)
            counterfactual = eltype(result).(CounterfactualExplanations.counterfactual(explanation))

            # Round the difference between old value and new value away from zero
            Δresult = round.(counterfactual - result, RoundFromZero)
            # Add it back to the new value
            result += Δresult
            prediction = predict_label(sim.model, sim.counterfactual_data, result)[1]

            result = reshape(result, size(result)[1], 1)
        end

        if i == 10
            println("Failed to find a suitable counterfactual")
        end
    end
    return vec(result) - factual
end