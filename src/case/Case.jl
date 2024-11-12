"""
Case defines utilities of a case study, e.g., the concrete logic of stages.
"""
module Case

    # Dependencies of Case
    using Agents
    using Bijections
    using CounterfactualExplanations
    using CSV
    using DataFrames
    using Distributions
    using Flux
    using Logging
    using MLJ
    using Tables
    using NeuroTreeModels
    using Random
    using StatsBase

    # Load definitions from Process that are necessary for Case
    using ..Process: Customer, Idle, Application, Decision, PostDecision
    using ..Process: ReceivingBenefits, Investigation, PostInvestigation, Recourse, process
    using ..Process: select_transition

    # Load stubs defined in SimulatedRecourse to be overriden in Case
    import ..idle_logic
    import ..application_logic
    import ..decision_logic
    import ..postdecision_logic
    import ..receiving_benefits_logic
    import ..investigation_logic
    import ..postinvestigation_logic
    import ..recourse_logic
    
    # Load Case module code
    include("initialization.jl")
    include("updates.jl")

    include("stages/idle.jl")
    include("stages/application.jl")
    include("stages/decision.jl")
    include("stages/postdecision.jl")
    include("stages/receiving_benefits.jl")
    include("stages/investigation.jl")
    include("stages/postinvestigation.jl")
    include("stages/recourse.jl")

end