"""
    update_agent!(agent::Customer, sim::ABM)

Update feature values of an agent such that their eligibility for assistance may change over time.
    
Required:
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function update_agent!(agent::Customer, sim::ABM)
    # On each step, increase the number of cycles since investigation, which resets in the Investigation stage
    if agent.status == :A
        agent.properties[:cycles_since_investigation] += 1
    end

    """
    We update the feature values for all agents using somewhat realistic values from Centraal Bureau voor de Statistiek.
    In the simulation we are working with a yearly cycle, i.e., the values are allowed to change once per year.
    Changes in features may affect both the eligibility for social benefits, as well as the amount of calculated assistance.
    """
    time = abmtime(sim)
    if time > 0 && time % 12 == 0
        agent.features["current_age"] += 1
        if sim.rotterdam
            sim.counterfactual_data.X[sim.feature_names[:persoon_leeftijd_bij_onderzoek], agent.id] += 1
        end

        """
        `total_income`, `total_assets`, `first_home_equity` tend to grow according to macroeconomic phenomena.
        Estimated based on YOY growth in statistics reported by CBS.
        
        Sources: 
            https://www.cbs.nl/en-gb/figures/detail/83740ENG
            https://longreads.cbs.nl/the-netherlands-in-numbers-2021/how-many-dwellings-in-the-netherlands/
        """
        agent.features["total_income"] = Integer(round(agent.features["total_income"] * 1.05))

        if agent.features["total_assets"] > 0
            agent.features["total_assets"] = Integer(round(agent.features["total_assets"] * 1.10))
        end

        if agent.features["first_home_equity"] > 0
            agent.features["first_home_equity"] = Integer(round(agent.features["first_home_equity"] * 1.13))
        end
        
        """
        Probability of a birth within a given year.
        Estimated as (number of births / total population) * 2 

        Source: 
            https://www.cbs.nl/en-gb/visualisations/dashboard-population/population-dynamics/birth
        """
        if rand(abmrng(sim), Uniform(0, 1)) < 0.019
            agent.features["children"] += 1
            if sim.rotterdam
                sim.counterfactual_data.X[sim.feature_names[:relatie_kind_huidige_aantal], agent.id] += 1
            end
        end

        """
        Probability of a child becoming an adult without tracking their age in the simulation.
        Estimated as 1 / (18 years)
        """
        if agent.features["children"] > 0 && rand(abmrng(sim), Uniform(0, 1)) < 0.055
            agent.features["children"] -= 1
            if sim.rotterdam
                sim.counterfactual_data.X[sim.feature_names[:relatie_kind_huidige_aantal], agent.id] -= 1
            end    
        end

        """
        Probability of a reduction in `total_assets`, e.g., due to a large purchase.
        The Beta(12, 2) distribution is chosen arbitrarily, values are strongly skewed towards 1, P(X > 0.8) = 0.766.
        """
        agent.features["total_assets"] -= Integer(round(agent.features["total_assets"] * (1 - rand(abmrng(sim), Beta(12, 2)))))

        """
        Probability of losing a partner, e.g., due to a break up, divorce, or death.
        Estimated as number of divorces / number of married couples, under the assumption that the value is not lower for co-habiting couples.

        Number of divorces in 2023: ≈24 k
        Number of married couples in 2023: ≈3.25 mln

        Sources:
            https://www.cbs.nl/en-gb/visualisations/dashboard-population/life-events/divorce
        """
        if agent.features["has_partner"] && rand(abmrng(sim), Uniform(0, 1)) < 0.0075
            agent.features["has_partner"] = false
            agent.features["total_income"] = agent.features["own_income"]
            agent.features["total_assets"] = Integer(round(agent.features["total_assets"] * rand(abmrng(sim), Uniform(0.5, 1.0))))
        end

        """
        Probability of moving in together with a new long-term partner.
        Estimated as (2 * number of new marriages and partnerships / population above 15 years old) * (number of couples living together / number of married couples).
        
        Number of new marriages and partnerships in 2023: ≈90 k
        Population above 15 years old in 2024: ≈15 mln
        Number of couples living together in 2024: ≈4.37 mln
        Number of married couples living together in 2024: ≈3.25 mln 

        Sources:
            https://www.cbs.nl/en-gb/visualisations/dashboard-population/population-pyramid
            https://www.cbs.nl/en-gb/figures/detail/37772eng?q=new%20marriages%20
            https://www.cbs.nl/nl-nl/visualisaties/dashboard-bevolking/woonsituatie/burgerlijke-staat
        """
        if !agent.features["has_partner"] && rand(abmrng(sim), Uniform(0, 1)) < 0.02
            agent.features["has_partner"] = true

            partner_income = (sample(abmrng(sim), [true, false], StatsBase.pweights([0.75, 0.25])) ? rand(abmrng(sim), Gamma(4, 800)) : 0) * 0.5
            agent.features["total_income"] = Integer(round(partner_income))
            agent.features["total_assets"] = Integer(round(agent.features["total_assets"] * rand(abmrng(sim), Uniform(1.0, 2.0))))
        end

        """
        Probability of losing employment or leaving the labor force.
        Estimated as (number of people leaving the labor market + number of people becoming unemployed) / size of the labor force

        Number of people leaving the labor market in Q2 2024: ≈213 k
        Number of people becoming unemployed in Q2 2024: ≈112 k
        Size of the labor force in Q2 2024: ≈13.4 mln

        Sources:
            https://www.cbs.nl/en-gb/news/2024/12/unemployment-continues-to-rise
            https://www.cbs.nl/en-gb/news/2024/29/unemployment-virtually-unchanged-in-june
        """
        if agent.features["own_income"] > 0 && rand(abmrng(sim), Uniform(0, 1)) < 0.025
            agent.features["total_income"] -= agent.features["own_income"]
            agent.features["own_income"] = 0
        end

        """
        Probability of finding an employment or joining the labor force.
        Estimated as (number of people joining the labor market + number of people finding a job) / size of the labor force

        Number of people joining the labor market in Q2 2024: ≈195 k
        Number of people finding a job in Q2 2024: ≈146 k
        Size of the labor force in Q2 2024: ≈13.4 mln

        We further assume the same probability of changing a job to a better paying one.

        Sources:
            https://www.cbs.nl/en-gb/news/2024/12/unemployment-continues-to-rise
            https://www.cbs.nl/en-gb/news/2024/29/unemployment-virtually-unchanged-in-june
        """

        new_income = Integer(round(rand(abmrng(sim), Gamma(4, 800))))
        if rand(abmrng(sim), Uniform(0, 1)) < 0.025 && (new_income > agent.features["own_income"])
            agent.features["own_income"] = new_income
            agent.features["total_income"] += agent.features["own_income"]
        end

        """
        Probability of moving, which may influence the number of cost sharers.
        Very crude estimation as this strongly depends on the age.

        Source:
            https://www.cbs.nl/nl-nl/nieuws/2024/22/iets-meer-verhuizingen-in-2023
        """
        if agent.features["first_home_equity"] == 0 && rand(abmrng(sim), Uniform(0, 1)) < 0.05
            adults = rand(abmrng(sim), truncated(Geometric(0.32), upper=10))
            agent.features["other_adults_in_household"] = adults
            if sim.rotterdam
                sim.counterfactual_data.X[sim.feature_names[:relatie_overig_actueel_vorm__kostendeler], agent.id] = adults
            end
        end
    end
end

"""
    attempt_recourse!(agent::Customer, sim::ABM)

Probabilistically implement an algorithmic recourse recommendation.

Required:
    - `agent` (Customer): the `agent` that is being processed.
    - `sim` (ABM): the complete simulation object.
"""
function attempt_recourse!(agent::Customer, sim::ABM)
    update_count = 0
    recommendation = agent.properties[:recommendation]
    for (index, feature) in enumerate(recommendation)

        # If there is no recourse to be implemented, continue to next feature
        if (recommendation[index] == 0) || (rand(abmrng(sim), Uniform(0, 1)) < sim.difficulty[index])
            continue
        end

        # This field depends on relatie_overig_actueel_vorm__kostendeler hence we set it separately
        if sim.feature_names(index) == :relatie_overig_kostendeler
            continue
        end

        # Simulations run in a monthly cycle but some features are counted in days/months
        # so we acommodate for the impact the agent may have on recommendation 
        impact = 1
        if sim.feature_names(index) in [:adres_dagen_op_adres]
            impact = 30
        # Age changes automatically in update_agent!
        elseif sim.feature_names(index) in [:persoon_leeftijd_bij_onderzoek]
            impact = 0
        end

        # Calculate new value if probabilistic change is successful
        # If recommended change is larger than 0, then the agent must increase the value of the feature
        if recommendation[index] > 0
            updated_rec_value = max(recommendation[index] - impact, 0)
            updated_feature_value = sim.counterfactual_data.X[index, agent.id] + impact
            sim.counterfactual_data.X[index, agent.id] = updated_feature_value
        # Otherwise, the agent must decrease the value of the feature by `impact`
        else
            updated_rec_value = min(recommendation[index] + impact, 0)
            updated_feature_value = sim.counterfactual_data.X[index, agent.id] + impact
            # Avoid going below 0 if impact is larger than the current value of the feature
            sim.counterfactual_data.X[index, agent.id] = max(updated_feature_value, 0)
        end
        # Update value in recommendation
        agent.properties[:recommendation][index] = updated_rec_value

        # `relationship_other_current_form_cost_sharer` influences other features
        if sim.feature_names(index) in [:relatie_overig_actueel_vorm__kostendeler]
            agent.features["other_adults_in_household"] = sim.counterfactual_data.X[index, agent.id]
            # If the new value for "cost sharers" is larger 0, the boolean "cost sharer" field should be 
            if sim.counterfactual_data.X[index, agent.id] > 0
                sim.counterfactual_data.X[sim.feature_names[:relatie_overig_kostendeler], agent.id] = true
                agent.properties[:recommendation][sim.feature_names[:relatie_overig_kostendeler]] = 1
            else
                sim.counterfactual_data.X[sim.feature_names[:relatie_overig_kostendeler], agent.id] = false
                agent.properties[:recommendation][sim.feature_names[:relatie_overig_kostendeler]] = 0
            end
        end

        update_count += 1
    end
    remaining_count = count(!iszero, recommendation)
    if remaining_count > 0
        Logging.@logmsg Logging.LogLevel(-3) "Agent $(agent.id) updated $update_count features ($remaining_count remaining)."
    else
        Logging.@logmsg Logging.LogLevel(-1) "Agent $(agent.id) successfully implemented the recommendation."
    end
end
