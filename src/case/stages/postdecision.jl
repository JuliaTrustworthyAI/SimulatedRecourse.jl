"""
    postdecision_logic(current_stage::PostDecision, agent::Customer, sim::ABM)

Execute the case-specific logic of the PostDecision stage.
Here, the `agent` may react to the outcome from the Decision stage.

Required:
    - `current_stage` (PostDecision): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function postdecision_logic(current_stage::PostDecision, agent::Customer, sim::ABM)
    # If the agent was approved for assistance, they automatically move to the ReceivingBenefits stage
    # Where they will remain unless selected for investigation or cancel their assistance.
    if agent.status == :A
        # From the moment of acceptance, the cycles since investigation start counting
        agent.properties[:cycles_since_investigation] = 0
        return move_agent!(agent, sim.stage_names["ReceivingBenefits"], sim)
    
    else
        # Otherwise, they move to another stage (i.e., back to Idle) with ReceivingBenefits banned from choice.
        # A rule-based system algorithmic recourse algorithm could allow for a recourse intervention at this stage.
        next_stage = select_transition(current_stage.data.next, [sim.stage_names["ReceivingBenefits"]]; rng=abmrng(sim))
        return move_agent!(agent, next_stage, sim)
    end
    return
end