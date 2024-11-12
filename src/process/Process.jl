"""
Process defines utilities independent of a specific case study.
"""
module Process

    # Dependencies of Process
    using Agents
    using Bijections
    using CSV
    using DataFrames
    using Distributions
    using Graphs
    using JSON
    using Logging
    using Random
    using StatsBase

    # Load logic functions as overriden in the Case module
    import ..idle_logic
    import ..application_logic
    import ..decision_logic
    import ..postdecision_logic
    import ..receiving_benefits_logic
    import ..investigation_logic
    import ..postinvestigation_logic
    import ..recourse_logic

    # Load Process module code
    include("definitions.jl")
    include("initialization.jl")
    include("utils.jl")
    include("stages.jl")

    # Export own definitions for the Case module
    export Customer

    export Idle
    export Application
    export Decision
    export PostDecision
    export ReceivingBenefits
    export Investigation
    export PostInvestigation
    export Recourse
    export Complaint

    export process

end