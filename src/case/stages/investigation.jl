"""
    investigation_logic(current_stage::Investigation, agent::Customer, sim::ABM)

Execute the case-specific logic of the Investigation stage.
Here, the department re-evaluates the eligibility of the `agent` for assistance.

Required:
    - `current_stage` (Investigation): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function investigation_logic(current_stage::Investigation, agent::Customer, sim::ABM)
    status, outcome = calculate_assistance(agent)

    # Allow agents to handle investigations that led to no change
    if status == agent.status && outcome == agent.outcome
        push!(agent.options, :NoChange)
    end

    agent.status = status
    agent.outcome = outcome

    # Agents do not react to the investigation in this stage.
    # Instead, they move to PostInvestigation to decide where to go next.
    agent.properties[:cycles_since_investigation] = 0
    return move_agent!(agent, sim.stage_names["PostInvestigation"], sim)
end