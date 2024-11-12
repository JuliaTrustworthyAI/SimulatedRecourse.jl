"""
    postinvestigation_logic(current_stage::PostInvestigation, agent::Customer, sim::ABM)

Execute the case-specific logic of the PostInvestigation stage.
Here, the `agent` may react to the outcome from the Investigation stage.

Required:
    - `current_stage` (PostInvestigation): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function postinvestigation_logic(current_stage::PostInvestigation, agent::Customer, sim::ABM)
    # The agent must have had an Accepted status to have ever been in the Investigation stage
    # So a Rejected status must have been assigned by the Investigation logic
    deleteat!(agent.options, agent.options .== :NoChange)
    agent.properties[:total_investigations] += 1
    
    # If agent was nominated randomly but remains approved, they move back to ReceivingBenefits
    if :Random in agent.options && agent.status == :A
        deleteat!(agent.options, agent.options .== :Random)
        return move_agent!(agent, sim.stage_names["ReceivingBenefits"], sim)
    
    # Else if agent was nominated randomly and gets rejected, they move to Idle
    elseif :Random in agent.options && agent.status == :R
        deleteat!(agent.options, agent.options .== :Random)
        return move_agent!(agent, sim.stage_names["Idle"], sim)

    # Else if an investigation did not change agents's status, we assume they may still ask for recourse
    elseif agent.status == :A
        next_stage = select_transition(current_stage.data.next, [sim.stage_names["Idle"]]; rng=abmrng(sim))
        return move_agent!(agent, next_stage, sim)
    
    # Else if an investigation changed the status, the agent may comply with the rejection and move to Idle,
    # or they may ask for Recourse, but they cannot directly move back to ReceivingBenefits 
    elseif agent.status == :R
        next_stage = select_transition(current_stage.data.next, [sim.stage_names["ReceivingBenefits"]]; rng=abmrng(sim))
        return move_agent!(agent, next_stage, sim)

    else
    end
    return
end