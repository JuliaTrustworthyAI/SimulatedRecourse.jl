"""
    decision_logic(current_stage::Decision, agent::Customer, sim::ABM)

Execute the case-specific logic of the Decision stage.
Here, the assistance standard applicable to the agent is calculated based on the Participation Act rules.

Required:
    - `current_stage` (Decision): the location of the `agent`.
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function decision_logic(current_stage::Decision, agent::Customer, sim::ABM)
    status, outcome = calculate_assistance(agent)
    agent.status = status
    agent.outcome = outcome
    # Agents do not react to the decision in this stage.
    # Instead, they move to PostDecision to decide where to go next.
    return move_agent!(agent, sim.stage_names["PostDecision"], sim)
end

"""
    calculate_assistance!(agent::Customer)

Applies the rules from the Participation Act to calculate the assistance standard for the `agent`.

Required:
    - `agent` (Customer): the `agent` that is being processed.
"""
function calculate_assistance(agent::Customer)
    status = :A

    # "You live in the Netherlands"
    if !agent.features["dutch_address"]
        status = :R
    end

    # "You are Dutch or you have a valid residence permit"
    if !agent.features["documented_residence"]
        status = :R
    end

    # "You are 18 years of age or older"
    if agent.features["current_age"] < 18
        status = :R
    end

    # "You are not eligible for any other form of assistance or benefit"
    if agent.features["eligible_other_assistance"]
        status = :R
    end

    # "You are not in prison or a detention center"
    if agent.features["imprisoned_or_detained"]
        status = :R
    end

    # "Is the equity in your home lower than €63,900 in 2024? And do you live in the home yourself?
    # Then you are entitled to assistance."
    if agent.features["first_home_equity"] >= 63900
        status = :R
    end

    # Shared household
    if agent.features["has_partner"] && (agent.features["total_assets"] > 15150)
        status = :R
    end

    # Single parent
    if !agent.features["has_partner"] && (agent.features["children"] > 0) && (agent.features["total_assets"] > 15150)
        status = :R
    end

    # Single
    if !agent.features["has_partner"] && (agent.features["children"] == 0) && (agent.features["total_assets"] > 7575)
        status = :R
    end

    assistance_standard = 0
    # Married or living together, 21 years to AOW retirement age
    if agent.features["has_partner"] && (agent.features["current_age"] < 67)
        assistance_standard = 1869

        # Single, 21 years to AOW retirement age
    elseif !agent.features["has_partner"] && (agent.features["current_age"] < 67)
        assistance_standard = 1308

        # Married or living together, from the AOW retirement age
    elseif agent.features["has_partner"] && (agent.features["current_age"] >= 67)
        assistance_standard = 1877

        # Single, from the AOW retirement age
    elseif !agent.features["has_partner"] && (agent.features["current_age"] >= 67)
        assistance_standard = 1457
    end

    # "With the cost-sharing standard, the number of housemates counts towards 
    # the amount of your social assistance benefit."
    cost_sharing = [1.0, 0.7, 0.5, 0.4333, 0.4, 0.38]
    # For proper indexing due to Julia's one-based system
    cost_sharers = agent.features["other_adults_in_household"] + 1
    # "The cost-sharing standard also applies to households with more than 5 people"
    cost_sharing_index = cost_sharers >= 6 ? 6 : cost_sharers
    # Assistance is equal to the difference between the standard and the (combined) income, 
    # multiplied by the `cost_sharing` standard
    outcome = Int(round(
        (assistance_standard - (agent.features["total_income"] * cost_sharing[cost_sharing_index]))
    ))

    # If agent does not fulfill requirements, the calculated assistance is 0
    if status != :A || outcome <= 0
        # Need to avoid situations where the agent is technically accepted, but the assistance is 0
        status = :R 
        outcome = 0
    end

    return status, outcome
end