ping = {
	while_cast = function(player)
		-- Show a self-only ping bubble at most once every 3 seconds while the duration is active
		local now = timeMS()
		local last = player.registry["ping_last_ms"] or 0
		if last == 0 or (now - last) >= 3000 then
			player.registry["ping_last_ms"] = now
			player:talkSelf(2, "Ping: " .. player.ping .. "ms")
		end
	end,

	requirements = function(player)
		local level = 5
		local item = {0}
		local amounts = {50}
		local txt = "In order to learn this spell, you must bring me:\n\n"
		for i = 1, #item do
			txt = txt .. "" .. amounts[i] .. " " .. Item(item[i]).name .. "\n"
		end

		local desc = {"A spell to light the way for you and your party.", txt}
		return level, item, amounts, desc
	end
}
