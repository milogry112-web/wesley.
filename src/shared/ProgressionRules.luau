--!strict
-- Engine-independent encounter rules, shared with executable CLI regression tests.
local Rules = {}
function Rules.NewEncounter(): {[number]: boolean}
	return {}
end

function Rules.Count(encounter: {[number]: boolean}): number
	local count = 0
	for slot = 1, 5 do
		if encounter[slot] then count += 1 end
	end
	return count
end

function Rules.RecordKill(encounter: {[number]: boolean}, zoneId: number, slotId: number, highest: number, completed: boolean): (number, boolean, boolean)
	if completed or zoneId ~= highest or slotId % 1 ~= 0 or slotId < 1 or slotId > 5 or encounter[slotId] then
		return highest, completed, false
	end
	encounter[slotId] = true
	if Rules.Count(encounter) == 5 then
		if highest == 30 then return 30, true, true end
		return highest + 1, false, true
	end
	return highest, false, true
end

return table.freeze(Rules)
