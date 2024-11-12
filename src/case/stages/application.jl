"""
    application_logic(current_stage::Application, agent::Customer, sim::ABM)

Execute the case-specific logic of the Application stage.
Here, simply move the agent to the Decision stage where their eligibility is evaluated.

Required:
    - `current_stage` (Application): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function application_logic(current_stage::Application, agent::Customer, sim::ABM)
    next_stage = select_transition(current_stage.data.next; rng=abmrng(sim))
    if next_stage != agent.pos
        return move_agent!(agent, next_stage, sim)
    end
end