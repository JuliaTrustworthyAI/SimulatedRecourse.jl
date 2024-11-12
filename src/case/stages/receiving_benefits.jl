"""
    receiving_benefits_logic(current_stage::ReceivingBenefits, agent::Customer, sim::ABM)

Execute the case-specific logic of the ReceivingBenefits stage.
Here, the `agent` is stored unless nominated for reinvestigation.
With a small probability they may also leave the social assistance program (e.g., corresponding to finding work).

Required:
    - `current_stage` (ReceivingBenefits): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function receiving_benefits_logic(current_stage::ReceivingBenefits, agent::Customer, sim::ABM)
    if !isnothing(agent.properties[:recommendation]) && !isempty(findall(!iszero, agent.properties[:recommendation]))
        attempt_recourse!(agent, sim)
    end

    # Allow the agent to sometimes self-evaluate eligibility and remove itself from the process if necessary
    if rand(abmrng(sim), Uniform(0, 1)) < (1 / 12)
        status, outcome = calculate_assistance(agent)
        if status == :R
            agent.status = status
            agent.outcome = outcome
            return move_agent!(agent, sim.stage_names["Idle"], sim)
        end
    end

    # Allow for nominations with limited frequency, nominate randomly and based on the model
    if agent.properties[:cycles_since_investigation] >= sim.investigation_freq
        # If nominate_model returns true, this corresponds to high risk score
        if nominate_model(agent, sim)
            # If the agent was nominated for investigation, they do not have a choice where to go in the next stage
            Logging.@logmsg Logging.LogLevel(-2) "Agent $(agent.id) nominated for investigation through method: Model."
            agent.properties[:model_investigations] += 1
            return move_agent!(agent, sim.stage_names["Investigation"], sim)

        elseif nominate_random(agent; p=sim.p_random_nomination, rng=abmrng(sim))
            # If the agent was nominated for investigation, they do not have a choice where to go in the next stage
            push!(agent.options, :Random)
            Logging.@logmsg Logging.LogLevel(-2) "Agent $(agent.id) nominated for investigation through method: Random."
            return move_agent!(agent, sim.stage_names["Investigation"], sim)
        end
    end

    # Otherwise, the agent will generally continue receiving assistance
    next_stage = select_transition(current_stage.data.next, [sim.stage_names["Investigation"]]; rng=abmrng(sim))
    if next_stage != agent.pos
        return move_agent!(agent, next_stage, sim)
    end
end

"""
    nominate_random(agent::Customer; p::Float64)

In every cycle, the agent may be nominated for reinvestigation by random selection.

Required:
    - `agent` (Customer): the `agent` that is being processed.

Optional:
    - `p` (Float64): the probability of a random selection.
"""
function nominate_random(agent::Customer; p::Float64 = 0.175, rng=Xoshiro(42))
    return rand(rng, Uniform(0, 1)) < p
end

"""
    nominate_model(agent::Customer, sim::ABM)

In every cycle, the agent may be nominated for reinvestigation by the model.

Required:
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object storing the reinvestigation model
"""
function nominate_model(agent::Customer, sim::ABM)
    # If no model is defined, simply return false.
    if isnothing(sim.model)
        return false
    end
    # Otherwise, use the model to predict the label (risk) of the specific agent.
    # If true (1), the risk is high, and so the nomination is issued by the model. 
    return predict_label(sim.model, sim.counterfactual_data, sim.counterfactual_data.X[:, agent.id])[1]
end