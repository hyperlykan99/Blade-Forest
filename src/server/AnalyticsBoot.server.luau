-- AnalyticsBoot (M0-F): starts the analytics baseline and connects it to DataService.
local DataService = require(script.Parent:WaitForChild("DataService"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
DataService.SetAnalytics(Analytics)
Analytics.Start(DataService)
