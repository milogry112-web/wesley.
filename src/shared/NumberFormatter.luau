--!strict
-- Display only. Calculations always use numeric values, never these strings.
local NumberFormatter = {}
local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function NumberFormatter.IsFinite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function NumberFormatter.Format(value: number): string
	if not NumberFormatter.IsFinite(value) then return "—" end
	local sign = if value < 0 then "-" else ""
	local scaled = math.abs(value)
	local index = 1
	while scaled >= 1000 and index < #suffixes do
		scaled /= 1000
		index += 1
	end
	if scaled >= 1000 then return string.format("%.2e", value) end
	-- Round before suffix selection so 999.96K displays 1M instead of 1000K.
	scaled = math.floor(scaled * 10 + 0.5) / 10
	if scaled >= 1000 and index < #suffixes then
		scaled /= 1000
		index += 1
	end
	local digits = string.format("%.1f", scaled):gsub("%.0$", "")
	return sign .. digits .. suffixes[index]
end

function NumberFormatter.Ratio(health: number, maximum: number): number
	if not NumberFormatter.IsFinite(health) or not NumberFormatter.IsFinite(maximum) or maximum <= 0 then return 0 end
	return math.clamp(health / maximum, 0, 1)
end

return table.freeze(NumberFormatter)
