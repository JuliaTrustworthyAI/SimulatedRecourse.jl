"""
    idle_logic(current_stage::Idle, agent::Customer, sim::ABM)

Execute the case-specific logic of the Idle stage.
Here, with some probability the agent moves from the environment to the decision-making process (applies for benefits).

Required:
    - `current_stage` (Idle): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function idle_logic(current_stage::Idle, agent::Customer, sim::ABM)
    if !isnothing(agent.properties[:recommendation]) && !isempty(findall(!iszero, agent.properties[:recommendation]))
        attempt_recourse!(agent, sim)
        # If external factors changed the values of an agent enough that they became eligible, take that into consideration
        status, outcome = calculate_assistance(agent)
        if status == :A
            next_stage = sim.stage_names["Application"]
        else
            next_stage = sim.stage_names["Idle"]
        end
    else
        next_stage = select_transition(current_stage.data.next; rng=abmrng(sim))
    end

    # Move to the next stage if the agent becomes active
    if next_stage != agent.pos
        return move_agent!(agent, next_stage, sim)
    end
end