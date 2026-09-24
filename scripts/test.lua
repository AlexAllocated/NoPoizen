-- Offline-only stand-ins. This file is deliberately excluded from the TOC.
local root = arg[1] or "."
_G.CreateFrame = function()
	return { SetScript = function() end, RegisterEvent = function() end, UnregisterEvent = function() end }
end
_G.wipe = function(t)
	for key in pairs(t) do
		t[key] = nil
	end
	return t
end
local namespace = {}
for line in io.lines(root .. "/NoPoizen.toc") do
	if line:match("%.lua$") then
		assert(loadfile(root .. "/" .. line))("NoPoizen", namespace)
	end
end
local ok = NoPoizen:RunTests(arg[2] == "reverse")
if not ok then
	os.exit(1)
end
