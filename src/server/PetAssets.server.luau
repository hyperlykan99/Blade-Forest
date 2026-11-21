local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local factory = require(script.Parent:WaitForChild("PetModelFactory"))
factory.Populate(ReplicatedStorage:WaitForChild("PetModels"), Config)
