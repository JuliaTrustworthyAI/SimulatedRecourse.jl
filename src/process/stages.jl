"""
    process(current_stage::Idle, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the Idle stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (Idle): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the Idle stage.
"""
function process(current_stage::Idle, agent::Customer, sim::ABM, stage_logic::Function=idle_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::Application, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the Application stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (Application): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the Application stage.
"""
function process(current_stage::Application, agent::Customer, sim::ABM, stage_logic::Function=application_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::Decision, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the Decision stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (Decision): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the Decision stage.
"""
function process(current_stage::Decision, agent::Customer, sim::ABM, stage_logic::Function=decision_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::PostDecision, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the PostDecision stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (PostDecision): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the PostDecision stage.
"""
function process(current_stage::PostDecision, agent::Customer, sim::ABM, stage_logic::Function=postdecision_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::ReceivingBenefits, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the ReceivingBenefits stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (ReceivingBenefits): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the ReceivingBenefits stage.
"""
function process(current_stage::ReceivingBenefits, agent::Customer, sim::ABM, stage_logic::Function=receiving_benefits_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::Investigation, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the Investigation stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (Investigation): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the Investigation stage.
"""
function process(current_stage::Investigation, agent::Customer, sim::ABM, stage_logic::Function=investigation_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::PostInvestigation, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the PostInvestigation stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (PostInvestigation): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the PostInvestigation stage.
"""
function process(current_stage::PostInvestigation, agent::Customer, sim::ABM, stage_logic::Function=postinvestigation_logic)
    stage_logic(current_stage, agent, sim)
    return
end

"""
    process(current_stage::Recourse, agent::Customer, sim::ABM, stage_logic::Function)

Execute the behavior of the simulation in the Recourse stage, taking advantage of multiple dispatch.
This depends on the concrete implementation of `stage_logic` which must be handled in Case.

Requires:
    - `current_stage` (Recourse): the location of the `agent` is provided implicitly.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object that may include properties accessed by the logic.
    - `stage_logic` (Function): the concrete implementation of the logic for the Recourse stage.
"""
function process(current_stage::Recourse, agent::Customer, sim::ABM, stage_logic::Function=recourse_logic)
    stage_logic(current_stage, agent, sim)
    return
end

