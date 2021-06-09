"""
    write_metadata_NDE_training(FILE_PATH, train_files, train_epochs, train_tranges, opts, uw_NN, vw_NN, wT_NN)
"""
function write_metadata_NDE_training(FILE_PATH, train_files, train_epochs, train_tranges, train_parameters, opts, uw_NN, vw_NN, wT_NN)
    jldopen(FILE_PATH, "w") do file
        training_info = JLD2.Group(file, "training_info")
        training_info["train_files"] = train_files
        training_info["train_epochs"] = train_epochs
        training_info["train_tranges"] = train_tranges
        training_info["optimizers"] = opts
        training_info["parameters"] = train_parameters
        training_info["uw_neural_network"] = uw_NN
        training_info["vw_neural_network"] = vw_NN
        training_info["wT_neural_network"] = wT_NN

        training_data = JLD2.Group(file, "training_data")
        loss = JLD2.Group(training_data, "loss")
        neural_network = JLD2.Group(training_data, "neural_network")
        uw = JLD2.Group(neural_network, "uw")
        vw = JLD2.Group(neural_network, "vw")
        wT = JLD2.Group(neural_network, "wT")
        η = JLD2.Group(training_data, "η")
        β = JLD2.Group(training_data, "β")
        state = JLD2.Group(training_data, "state")
    end
end

function write_data_NDE_training(FILE_PATH, loss, uw_NN, vw_NN, wT_NN, stage, optimizer)
    jldopen(FILE_PATH, "a") do file
        if !haskey(file, "training_data/loss/$stage")
            file["training_data/loss/$stage/1"] = loss
        else
            count = length(keys(file["training_data/loss/$stage"])) + 1
            file["training_data/loss/$stage/$count"] = loss
        end

        if !haskey(file, "training_data/neural_network/uw/$stage")
            file["training_data/neural_network/uw/$stage/1"] = uw_NN
        else
            count = length(keys(file["training_data/neural_network/uw/$stage"])) + 1
            file["training_data/neural_network/uw/$stage/$count"] = uw_NN
        end

        if !haskey(file, "training_data/neural_network/vw/$stage")
            file["training_data/neural_network/vw/$stage/1"] = vw_NN
        else
            count = length(keys(file["training_data/neural_network/vw/$stage"])) + 1
            file["training_data/neural_network/vw/$stage/$count"] = vw_NN
        end

        if !haskey(file, "training_data/neural_network/wT/$stage")
            file["training_data/neural_network/wT/$stage/1"] = wT_NN
        else
            count = length(keys(file["training_data/neural_network/wT/$stage"])) + 1
            file["training_data/neural_network/wT/$stage/$count"] = wT_NN
        end

        if !haskey(file, "training_data/η/$stage")
            file["training_data/η/$stage/1"] = optimizer.eta
        else
            count = length(keys(file["training_data/η/$stage"])) + 1
            file["training_data/η/$stage/$count"] = optimizer.eta
        end

        if !haskey(file, "training_data/β/$stage")
            file["training_data/β/$stage/1"] = optimizer.beta
        else
            count = length(keys(file["training_data/β/$stage"])) + 1
            file["training_data/β/$stage/$count"] = optimizer.beta
        end

        if !haskey(file, "training_data/state/$stage")
            file["training_data/state/$stage/1"] = optimizer.state
        else
            count = length(keys(file["training_data/state/$stage"])) + 1
            file["training_data/state/$stage/$count"] = optimizer.state
        end
    end
end

function write_metadata_NN_training(FILE_PATH, train_files, train_epochs, opts, NN, NN_type)
    jldopen(FILE_PATH, "w") do file
        training_info = JLD2.Group(file, "training_info")
        training_info["train_files"] = train_files
        training_info["train_epochs"] = train_epochs
        training_info["optimizers"] = opts
        training_info["$(NN_type)_neural_network"] = NN
        training_data = JLD2.Group(file, "training_data")
    end
end

function write_data_NN_training(FILE_PATH, loss, NN)
    jldopen(FILE_PATH, "a") do file
        if !haskey(file, "training_data/loss")
            file["training_data/loss/1"] = loss
        else
            count = length(keys(file["training_data/loss"])) + 1
            file["training_data/loss/$count"] = loss
        end

        if !haskey(file, "training_data/neural_network")
            file["training_data/neural_network/1"] = NN
        else
            count = length(keys(file["training_data/neural_network"])) + 1
            file["training_data/neural_network/$count"] = NN
        end

    end
end

function write_data_NN(FILE_PATH, uw_NN, vw_NN, wT_NN)
    jldopen(FILE_PATH, "w") do file
        file["neural_network/uw"] = uw_NN
        file["neural_network/vw"] = vw_NN
        file["neural_network/wT"] = wT_NN
    end
end

function write_metadata_modified_pacanowski_philander_optimisation(FILE_PATH, train_files, train_epochs, train_tranges, train_parameters, opts)
    jldopen(FILE_PATH, "w") do file
        training_info = JLD2.Group(file, "training_info")
        training_info["train_files"] = train_files
        training_info["train_epochs"] = train_epochs
        training_info["train_tranges"] = train_tranges
        training_info["optimizers"] = opts
        training_info["parameters"] = train_parameters

        training_data = JLD2.Group(file, "training_data")
        loss = JLD2.Group(training_data, "loss")
        parameters = JLD2.Group(training_data, "parameters")
    end
end

function write_data_modified_pacanowski_philander_optimisation(FILE_PATH, loss, parameters)
    jldopen(FILE_PATH, "a") do file
        if !haskey(file, "training_data/loss")
            file["training_data/loss/1"] = loss
        else
            count = length(keys(file["training_data/loss"])) + 1
            file["training_data/loss/$count"] = loss
        end

        if !haskey(file, "training_data/parameters")
            file["training_data/parameters/1"] = parameters
        else
            count = length(keys(file["training_data/parameters"])) + 1
            file["training_data/parameters/$count"] = parameters
        end

    end
end