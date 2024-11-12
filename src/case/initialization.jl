"""
    get_rotterdam_data(filename::String; target::Symbol, threshold::Float64, exclude_features::Vector{Symbol})

Parse the Rotterdam dataset provided in the format of the Lighthouse synthetic data generation file.
Most importantly, the risk scores are represented as two features: "Ja" (high risk) and "Nee" (1-Ja),
we need to convert these continuous features into labels, this happens by comparing it against `threshold`.

Required:
    - filename (String): path to the `.csv' file storing the dataset for reinvestigations.

Optional:
    - target (Symbol): the name of the target feature.
    - threshold (Float64): a value that is used as the cut-off point for high risk scores, default comes from Rotterdam.
    - exclude_features (Vector{Symbol}): a list of features to be excluded from consideration.  
"""
function get_rotterdam_data(filename::String; target::Symbol=:Ja, threshold::Float64=0.6970136,
                            exclude_features::Vector{Symbol}=Symbol[])
    # Read synthetic data
    data = DataFrame(CSV.File(filename))
    # Exclude features based on list
    data = DataFrames.select!(data, Not(exclude_features))
    # Convert risk score to label based on the provided threshold
    # i.e., if label Ja ("Yes fraud") is larger than threshold this qualifies as high risk
    # Predicting "No" has expected accuracy of ~85% 
    data[!, :y] = data[!, target] .> threshold
    # Remove risk score columns
    data = DataFrames.select!(data, Not([:Ja, :Nee]))
    # Split into features and labels
    X = DataFrames.select(data, Not(:y))
    y = Bool.(data[:, :y])
    feature_names = Dict([(Symbol(name), id) for (id, name) in enumerate(names(X))])

    return X, y, Bijection(feature_names)
end

"""
    get_synthetic_data(filename::String; N::Int, f_max::Int)

Load a synthetic dataset of blobs, or create and preserve it if the specified file does not exist.

Required:
    - `filename` (String): name of the file for the dataset

Optional:
    - `N` (Int): number of samples to be generated, defaults to the Rotterdam dataset size.
    - `f_max` (Int): maximum acceptable value for the features.

"""
function get_synthetic_data(filename::String; N::Int=12645, f_max::Int=2)
    # If possible, use the existing data
    if isfile(filename)
        data = DataFrame(CSV.File(filename))
        X = DataFrames.select(data, Not(:y))
        y = data[:, :y]
        feature_names = Dict([(Symbol(name), id) for (id, name) in enumerate(names(X))])
    
    # Otherwise create a new dataset and store it
    else
        X, y = make_blobs(N, 2; centers=2, as_table=false, center_box=(-f_max => f_max), cluster_std=0.1)
        X = DataFrame(X, ["feature_a", "feature_b"])
        y .= (y .== 2)
        feature_names = Dict(:feature_a => 1, :feature_b => 2)

        data = X
        data.y = y
        CSV.write(filename, data)
    end

    return X, Bool.(y), Bijection(feature_names)
end

"""
    generate_dataset(; n_agents::Int, input::String, output::String)

Generate a dataset of agents for the simulations.

Optional:
    - `n_agents` (Int): the total number of agents to be generated, defaults to the size of the Lighthouse dataset.
    - `input` (String): the path to the `.csv' file storing the dataset for reinvestigations.
    - `output` (String): the path to the `.csv` file where the new dataset should be stored.
"""
function generate_dataset(; n_agents::Int=12645, input::String="data/rotterdam/investigation_test.csv", output::String="data/rotterdam/decision_data.csv")
    investigation_data = nothing
    if !isnothing(input)
        investigation_data = CSV.read(input, DataFrame)
    end

    CSV.write(output, DataFrame([generate_agent(i, i; investigation_data) for i in 1:n_agents]))
end

"""
    generate_agent(id::Int, seed::Int; investigation_data::DataFrame)

Data from Lighthouse Reports does not include all features required to evaluate the eligibility of an agent for welfare.
Thus, we make use of the data wherever possible and otherwise fill in the blanks using estimates based on CBS statistics.

As (theoretically) all samples in Lighthouse data refer to agents that have been eligible for welfare,
we know the ground truth, and we are able to see if the model targets agents who remain eligible even if their features change.

To remain compatible with the Rotterdam model, some features are stored in two dataframes.

Required:
    - `id` (Int): the ID of the agent, assigned automatically when the simulation is instantiated.
    - `seed` (Int): the seed for the random operations, assigned automatically when the simulation is instantiated.

Optional:
    - `investigations_data` (DataFrame): the data from Rotterdam will influence the values of some features.
"""
function generate_agent(id::Int, seed::Int; investigation_data::DataFrame=nothing)
    rng = Random.Xoshiro(seed)

    if isnothing(investigation_data)
        """
        Very difficult to estimate but this feature should be largely subsumed by `dutch_nationality` and `residence_permit`.
        """
        dutch_address = sample(rng, [true, false], StatsBase.pweights([0.995, 0.005]))
        
        """
        Age is not distributed normally and the Gamma distribution is still heavily inaccurate,
        but ultimately this does not have a major impact on the analysis.

        Sources:
            https://www.cbs.nl/en-gb/visualisations/dashboard-population/population-pyramid
            https://www.cbs.nl/en-gb/visualisations/dashboard-population/age/age-distribution
        """
        current_age = rand(rng, truncated(Gamma(5, 9), upper=100))
        
        """
        "At the beginning of 2024, 44.2 percent of the inhabitants aged 15 years or older had the status 'married', which also includes civil partnership".
        This does not account for unformalized relationships which we treat separately under the `cohabitation` feature.

        Source:
            https://www.cbs.nl/nl-nl/visualisaties/dashboard-bevolking/woonsituatie/burgerlijke-staat
        """
        married = sample(rng, [true, false], StatsBase.pweights([0.442, 0.558]))
        
        """
        Values estimated directly from the Lighthouse Reports synthetic data.
        This feature is not considered in the decision-making so it may be removed later.

        Source:
            https://github.com/Lighthouse-Reports/suspicion_machine/blob/main/data/01_raw/synth_data.csv
        """
        work_obligation_exemption = sample(rng, [true, false], StatsBase.pweights([0.318, 0.682]))
        
        """
        Average household involves 2.11 people, ideally we should care only about adults here but this is difficult to estimate.

        Source:
            https://www.cbs.nl/en-gb/figures/detail/82905ENG?q=household%20size
        """
        other_adults_in_household = rand(rng, truncated(Geometric(0.32), upper=10))

        """
        "In 2023, the total fertility rate was 1.43".
           
        Source:
            https://www.cbs.nl/en-gb/news/2024/18/over-75-thousand-women-became-first-time-mothers-in-2023
        """
        children = rand(rng, Geometric(0.4))

    else
        """
        Wherever possible we use the synthetic features, although their reliability/accordance with business rules is questionable.
        """
        investigation_features = investigation_data[id, :]
        dutch_address = Bool(investigation_features["adres_recentst_onderdeel_rdam"])
        current_age = investigation_features["persoon_leeftijd_bij_onderzoek"]
        married = Bool(investigation_features["relatie_partner_huidige_partner___partner__gehuwd_"])
        work_obligation_exemption = Bool(investigation_features["ontheffing_actueel_ind"])
        other_adults_in_household = investigation_features["relatie_overig_actueel_vorm__kostendeler"]
        # There exist business rules regarding the number of children but it looks like they are not followed in the dataset...
        children = investigation_features["relatie_kind_huidige_aantal"]
    end

    """
    "Op 1 januari 2024 waren er 1,12 miljoen ongehuwde stellen".

    Estimated as (2 * 1.12) / (15 - 2 * 3.25) = 0.264,
    or the probability that a person above 15 years of age lives with a partner but they are not married.

    Population above 15 years old in 2024: ≈15 mln
    Number of married couples in 2024: 3.25 mln 
    Number of unmarried couples in 2024: 1.12 mln

    Sources:
        https://www.cbs.nl/en-gb/visualisations/dashboard-population/population-pyramid
        https://www.cbs.nl/nl-nl/visualisaties/dashboard-bevolking/woonsituatie/burgerlijke-staat
    """
    cohabitation = married ? false : sample(rng, [true, false], StatsBase.pweights([0.264, 0.736]))

    """
    Represents both formalized and unformalized partnerships since the type of a relationship does not matter for the decision-making.
    """
    has_partner = married || cohabitation
    
    """
    "Of the 17.6 million people who lived in the Netherlands on 1 January 2022, 86 percent were born in the Netherlands".

    Source:
        https://longreads.cbs.nl/the-netherlands-in-numbers-2022/where-were-people-in-the-netherlands-born/
    """
    dutch_nationality = sample(rng, [true, false], StatsBase.pweights([0.86, 0.14]))

    """
    "The number of undocumented migrants living in the Netherlands, according to the most recent estimation, lay between 23,000 and 58,000".
    We assume the higher end of the values, especially as they are likely to have increased.

    Source:
        https://doi-org.tudelft.idm.oclc.org/10.1080/15562948.2023.2235674
    """
    residence_permit = dutch_nationality ? false : sample(rng, [true, false], StatsBase.pweights([0.995, 0.005]))

    documented_residence = dutch_nationality || residence_permit

    """
    Roughly 25% of inhabitants are not in the labour force. For working people, the median income is €39.1k per year.
    This results in ≈€3200 per month which we estimate following Gamma(4, 800) distribution.

    Sources:
        https://longreads.cbs.nl/the-netherlands-in-numbers-2023/what-is-working-peoples-income/
        https://www.cbs.nl/en-gb/figures/detail/82309eng
    """
    own_income = (sample(rng, [true, false], StatsBase.pweights([0.75, 0.25])) 
                    ? rand(rng, Gamma(4, 800)) : 0) * 0.25

    """
    Same estimation as for the variable `own_income` for simplicity.
    """
    partner_income = (has_partner ? (sample(rng, [true, false], StatsBase.pweights([0.75, 0.25])) 
                        ? rand(rng, Gamma(4, 800)) : 0) : 0) * 0.25

    """
    If an applicant has a partner, their incomes are always considered together for the purposes of social welfare.
    "Are you married or living together? Or do you have a  joint household  with someone else? 
    Then the joint income and joint assets of you and your partner count."

    Our assumptions on income frequently lead to non-positive assistance (i.e., the agents earn too much to receive benefits)
    so for the purposes of the simulations these are scaled by 0.5 on lines 199 and 205
    """
    total_income = own_income + partner_income

    """
    Median wealth of a private household is €135.1k but for people on unemployment benefits only €38.4k, so we estimate with that in mind.
    Total assets implicitly include, e.g., debts and equity from ownership of estate; these are considered in the social welfare decision-making
    but there is ultimately no need to separately estimate them.
    
    Source:
        https://www.cbs.nl/en-gb/figures/detail/83739ENG?q=welfare
    """
    total_assets = rand(rng, Gamma(4, 10500)) * 0.5

    """
    "Seven in 10 dwellings in Amsterdam are rental properties".
    Thus we could assume that 30% of the population owns a home, but this leads to unnecessarily many rejections.

    For the purposes of the simulations we assume fewer people to own a home.

    Source:
        https://longreads.cbs.nl/the-netherlands-in-numbers-2021/how-many-dwellings-in-the-netherlands/
    """
    first_home_equity = (sample(rng, [true, false], StatsBase.pweights([0.1, 0.9])) ?
                         rand(rng, truncated(Normal(366000.0, 80000.0), lower=100000.0)) : 0)
    
    """
    Around 5 mln people in the Netherlands receive some form of social support, including Participatiewet benefits.
    Roughly 43.5 out of 1000 citizens in larger cities (weighted average of top 10 cities by population) fall under Participatiewet
    These Top 10 cities include a total of 3.75 mln people, meaning ≈1.06 mln on benefits of which 163k covered by Participatiewet.

    This would mean that only 15.3% of agents become active in the simulation so we exclude this factor,
    assuming that all agents who apply for Participatiewet benefits have no other choice. 
    This is also in line with the fact that we are using Rotterdam data.
    
    Sources:
        https://www.cbs.nl/en-gb/figures/detail/37789eng
        https://www.cbs.nl/nl-nl/deelnemers-enquetes/decentrale-overheden/soc-zekerheid-overheid/bijstandsuitkeringenstatistiek--bus--
    """
    eligible_other_assistance = false

    """
    Netherlands has a very low incarceration rate; in practice this feature should not play a role in the simulations.

    Source:
        https://www.cbs.nl/en-gb/news/2022/44/more-prison-detainees-in-2021
    """
    imprisoned_or_detained = sample(rng, [true, false], StatsBase.pweights([0.002, 0.998]))

    return (id=id,
            dutch_address=dutch_address,
            documented_residence=documented_residence,
            current_age=Integer(round(current_age)),
            own_income=Integer(round(own_income)),
            total_income=Integer(round(total_income)),
            total_assets=Integer(round(total_assets)),
            first_home_equity=Integer(round(first_home_equity)),
            eligible_other_assistance=eligible_other_assistance,
            imprisoned_or_detained=imprisoned_or_detained,
            work_obligation_exemption=work_obligation_exemption,
            other_adults_in_household=other_adults_in_household,
            children=children,
            has_partner=has_partner)
end 