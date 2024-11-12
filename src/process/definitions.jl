"""
Represents a Customer in the social assistance process.
"""
@agent struct Customer(GraphAgent)
    features::DataFrameRow
    status::Symbol = :U
    outcome::Int = 0
    options::Vector{Symbol} = Vector{Symbol}()
    properties::Dict{Symbol, Any} = Dict()
end

"""
Represents an arbitrary stage in the simulation
"""
abstract type SimulationStage end

"""
Represents the metadata stored in nodes of the Graph of GraphSpace. 

"""
abstract type GraphData end

"""
Concrete implementation of GraphData for simulations of social welfare processes.
"""
mutable struct StageData <: GraphData
    previous::Vector{Int}
    next::Dict{Int, Float64}
end

"""
Represents an arbitrary stage that falls outside of a simulation boundary.
Nodes of type EnvironmentStage store agents not actively participating in the social welfare process.
"""
abstract type EnvironmentStage <: SimulationStage end

"""
Concrete implementation of EnvironmentStage that is populated by agents outside of the social welfare process.
Agents at this node may be, for instance, considered employed or removed from a benefits scheme.
"""
struct Idle <: EnvironmentStage
    data::StageData
end

"""
Represents an arbitrary stage that is an active component of the simulation, within the simulation boundary.
Nodes of type SystemStage represent parts of the process where actions are taken by the organization.
"""
abstract type SystemStage <: SimulationStage end

"""
Represents an arbitrary stage that is an active component of the simulation, within the simulation boundary.
Nodes of type AgentStage represent parts of the process where actions are taken by the organization.
"""
abstract type AgentStage <: SimulationStage end

"""
Concrete implementation of AgentStage that is populated by agents who have submitted their applications.
Agents are moved to this node when they decide to apply for social welfare, but before their application is processed.
Main focus: action of the agents.
"""
struct Application <: AgentStage
    data::StageData
end

"""
Concrete implementation of SystemStage that is populated by agents whose applications are being considered.
Implements the logic used to decide whether an agent should be granted the benefits.
May also implement the logic to decide the amount of benefits in case this is not equal for all agents.
Main focus: reaction of the system to the application of the agents.
"""
struct Decision <: SystemStage
    data::StageData
end

"""
Concrete implementation of AgentStage that is populated by agents who are deciding how to react to the evaluation.
Implements the logic used by an agent to decide whether to seek recourse or complain against the decision.
Main focus: reaction of the agents to the decision of the system.
"""
struct PostDecision <: AgentStage
    data::StageData
end

"""
Concrete implementation of SystemStage that is populated by agents who are receiving benefits.
Agents are moved to this node if they are eligible for benefits, and stay here as long as they remain eligible.
Also, the node nominates agents for investigation using a pre-determined selection method.
Main focus: "storage" for agents.
"""
struct ReceivingBenefits <: SystemStage
    data::StageData
end

"""
Concrete implementation of SystemStage that is populated by agents who are being actively investigated.
Implements the logic used to decide whether the agent should be removed from the social welfare process.
Main focus: action of the system to evaluate the eligibility of an agent.
"""
struct Investigation <: SystemStage
    data::StageData
end

"""
Concrete implementation of AgentStage that is populated by agents who are deciding how to react to the investigation.
Implements the logic used by an agent to decide whether to seek recourse or complain against the decision.
Main focus: reaction of the agents to the decision of the system.
"""
struct PostInvestigation <: AgentStage
    data::StageData
end

"""
Concrete implementation of AgentStage that is populated by agents who are pursuing algorithmic recourse.
At this stage a decision is assumed to be correct but unwanted; however, based on the provided algorithmic recourse
agents may decide to move to a Complaint node if they believe a decision is not only unwanted but also incorrect.
Main focus: generation of recourse by the system.
"""
struct Recourse <: AgentStage
    data::StageData
end

"""
Concrete implementation of AgentStage that is populated by agents who have filed a complaint.
Implements the logic of an independent consultant deciding whether an earlier decision was handled correctly.
Main focus: re-evaluation of a decision by the system.
"""
struct Complaint <: AgentStage
    data::StageData
end