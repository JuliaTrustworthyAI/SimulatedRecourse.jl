"""
    train_model(data_path::String, config_path::String, output_path::String, process_data::Function)

Helper function to pretrain a model that will be used to nominate for investigations.

Required:
    - `data_path` (String): path to the `.csv' file storing the dataset for reinvestigations.
    - `config_path` (String): path to the `.json` file storing the configuration of the model.
    - `output_path` (String): path to store the reinvestigation model in .bson format.
    - `process_data` (Function): a function that outputs X, y, and names of the features for some dataset.
    - `model_name` (Symbol): the name of a model as defined in CounterfactualExplanations.jl catalogue
"""
function train_model(data_path::String="data/rotterdam/investigation_train_original.csv",
                     config_path::String="data/rotterdam/investigation_config.json",
                     output_path::String="data/rotterdam/investigation_model.bson",
                     process_data::Function=get_rotterdam_data,
                     model_name::Symbol=:NeuroTreeModel)

    X, y, _ = process_data(data_path)
    categorical, continuous, domain, mutability = parse_config(config_path)
    counterfactual_data = CounterfactualData(
        table(Tables.matrix(X)), y;
        features_categorical=categorical,
        features_continuous=continuous,
        domain=domain,
        mutability=mutability
    )

    model = CounterfactualExplanations.Models.fit_model(counterfactual_data, model_name)
    # Serialize trained model to reuse it for all agents
    BSON.@save output_path model
    return model
end

"""
    evaluate_model(data_path::String, config_path::String, model_path::String, process_data::Function)

Helper function to evaluate the accuracy of the pretrained model.

Required:
    - `data_path` (String): path to the `.csv' file storing the dataset for reinvestigations, preferably test set.
    - `config_path` (String): path to the `.json` file storing the configuration of the model.
    - `model_path` (String): path to the `.bson` file storing the reinvestigation model.
    - `process_data` (Function): a function that outputs X, y, and names of the features for some dataset.
"""
function evaluate_model(data_path::String="data/rotterdam/investigation_test.csv",
                        config_path::String="data/rotterdam/investigation_config.json",
                        model_path::String="data/rotterdam/investigation_model.bson",
                        process_data::Function=get_rotterdam_data)
    BSON.@load model_path model

    X, y, _ = process_data(data_path)
    categorical, continuous, domain, mutability = parse_config(config_path)
    counterfactual_data = CounterfactualData(
        table(Tables.matrix(X)), y;
        features_categorical=categorical,
        features_continuous=continuous,
        domain=domain,
        mutability=mutability
    )

    predictions = predict_label(model, counterfactual_data)
    acc = 0
    for (idx, val) in enumerate(y)
        if val == predictions[idx]
            acc += 1
        end
    end

    # Reinvestigation_model_large achieves ~94% accuracy on test set
    println("Surrogate model with accuracy: ", acc / length(y))
end

"""
    print_mutability(filename::String)

Helper function to convert mutability constraints from CSV into config format.

Require:
    - filename (String): path to the `.csv` file storing the description of the dataset.
"""
function print_mutability(filename::String="data/rotterdam/data_description+constraints.csv")
    data = DataFrame(CSV.File(filename))
    for (idx, val) in enumerate(data[!, :Mutability])
        print("\"", val, "\", ")
        if idx % 10 == 0
            println()
        end
    end
end

"""
    print_domain(filename::String)

Helper function to convert domain constraints from CSV into config format.

Require:
    - filename (String): path to the `.csv` file storing the description of the dataset.
"""
function print_domain(filename::String="data/rotterdam/data_description+constraints.csv")
    data = DataFrame(CSV.File(filename))
    for (idx, val) in enumerate(eachrow(data[!, [:Low, :High]]))
        print("[", val[:Low], ", ", val[:High], "], ")
        if idx % 10 == 0
            println()
        end
    end
end