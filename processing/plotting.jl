using CairoMakie
using CSV
using DataFrames
using JSON
using StatsBase

"""
Generate Figure 10.3
"""
no_model = JSON.parsefile("outputs/no_model.json")
model = JSON.parsefile("outputs/model.json")
recourse = JSON.parsefile("outputs/recourse.json")

total_agents = 2500
agent_no_model = no_model["agent_distribution"] / total_agents
mean_no_model = mean(agent_no_model)
push!(mean_no_model, 0)
std_no_model = std(agent_no_model)
push!(std_no_model, 0)

agent_model = model["agent_distribution"] / total_agents
mean_model = mean(agent_model)
push!(mean_model, 0)
std_model = std(agent_model)
push!(std_model, 0)

agent_recourse = recourse["agent_distribution"] / total_agents
mean_recourse = mean(agent_recourse)
std_recourse = std(agent_recourse)

heights = vcat(mean_no_model, mean_model, mean_recourse)
# 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8
tbl = (cat = [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8],
       height = heights,
       grp = [1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3],
       err = vcat(std_no_model, std_model, std_recourse),
       labels = rpad.(round.(heights, digits=3), 5, "0")
       )
dodge_gap = 0.05
gap = 0.25
wd = 1
function compute_x(x, width, gap, dodge, dodge_gap)
    scale_width(dodge_gap, n_dodge) = (1 - (n_dodge - 1) * dodge_gap) / n_dodge
    function shift_dodge(i, dodge_width, dodge_gap)
        (dodge_width - 1) / 2 + (i - 1) * (dodge_width + dodge_gap)
    end
    width *= 1 - gap
    n_dodge = maximum(dodge)
    dodge_width = scale_width(dodge_gap, n_dodge)
    shifts = shift_dodge.(dodge, dodge_width, dodge_gap)
    return x .+ width .* shifts
end
xerr = compute_x(tbl.cat, wd, gap, tbl.grp, dodge_gap)

with_theme(theme_latexfonts()) do
    fig = Figure()

    xticks = (1:8, ["Idle", "Application", "Decision", "PostDecision", "ReceivingBenefits",
                    "Investigation", "PostInvestigation", "Recourse"])

    # title = "Mean proportion of agents per stage by study at t = 264"
    title=""
    colors = Makie.wong_colors()
    ax = Axis(fig[1, 1];
              title, 
              xlabel = "Stage of the decision-making process", 
              ylabel = "Mean proportion of agents (total = 2500)", 
              xlabelpadding=20,
              xticks=xticks, 
              xticklabelsize=12, 
              xticklabelrotation=45,
              ylabelpadding=15,
              xgridvisible = false, 
              ygridvisible = false)

    ylims!(ax, 0.0, 0.4)
    barplot!(ax,
            tbl.cat,
            tbl.height, 
            bar_labels = tbl.labels, 
            gap=gap,
            dodge_gap=dodge_gap,
            label_rotation=0.5π, 
            label_offset = 20,
            label_size = 12,
            dodge = tbl.grp, 
            color = colors[tbl.grp])

    errorbars!(ax, xerr, tbl.height, tbl.err; whiskerwidth = 6, linewidth = 0.8, color=:black)
    labels = ["Model ✗  Recourse ✗", "Model ✓  Recourse ✗", "Model ✓  Recourse ✓"]
    elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]

    axislegend(ax,
               elements, 
               labels, 
               "Study", 
               framevisible = false, 
               position = :rt, 
               patchsize = (10, 10),
               titlesize=12,
               labelsize=12)

    save("outputs/summary.png", fig; px_per_unit=5.0)
    fig
end
