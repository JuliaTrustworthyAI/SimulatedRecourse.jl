using CairoMakie
using CSV
using DataFrames
using JSON
using StatsBase

"""
Parse data for Table 10.1
"""
no_model = JSON.parsefile("outputs/no_model.json")
model = JSON.parsefile("outputs/model.json")
recourse = JSON.parsefile("outputs/recourse.json")
studies = [no_model, model, recourse]

for (index, dict) in enumerate(studies)
    println("Parsing dict $index")
    for k in keys(dict)
        if all(x -> isnothing(x), dict[k])
            continue
        end
        mean_val = round.(mean(dict[k]), digits=3)
        std_val = round.(std(dict[k]), digits=3)
        println("$k --- mean: $mean_val --- std: $std_val")
    end
end