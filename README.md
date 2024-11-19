# `SimulatedRecourse.jl`
⚠ This README is a work-in-progress ⚠


## About

`SimulatedRecourse.jl` is an agent-based modeling (ABM) tool developed to simulate the dynamics of algorithmic recourse (AR) mechanisms in decision-making systems. 

Algorithmic recourse is, by nature, a practical problem. It can be seen as a form of a complaint process where an individual unhappy with a decision engages with the issuing organization to learn about the ways to receive a better outcome in the future. This means that supporting the adoption of AR mechanisms by organizations requires accounting for the dynamics of the decision-making process. `SimulatedRecourse.jl` is a proof-of-concept solution that supports this broader outlook on AR.

Specifically, we developed this tool to evaluate the potential value of algorithmic recourse to mitigate the negative impacts of model-driven social welfare fraud detection systems. Our research builds upon the publication of [Lighthouse Reports on "suspicion machines"](https://www.lighthousereports.com/investigation/suspicion-machines/) and relies on the data made available by the journalists.


## Set-up

Before `SimulatedRecourse.jl` is released as a package, you can install it from the repository as:

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaTrustworthyAI/SimulatedRecourse.jl")
```

To reproduce our experiments, you will also need to download the data from [the secondary repository](https://github.com/abuszydlik/Social-Welfare-Dataset/tree/main/rotterdam) (on a different license) and place the complete `rotterdam/` directory in `data/`. Afterward, you can run experiments with:

```julia
run_experiment(config::String; n_repetitions::Int, steps::Int, write_files::Bool)
```