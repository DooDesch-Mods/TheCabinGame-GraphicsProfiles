local M = {}
function M.apply(adapter,previousStore,profile)
    local before = adapter:read()
    local target
    if profile=="restore" then
        assert(previousStore.values.available,"No previous graphics profile")
        target = previousStore.values
    else
        local level = profile=="balanced" and 1 or profile=="performance" and 0
        assert(level,"invalid graphics profile")
        target = {gi=level,shadows=level,reflections=level,effects=level}
        local backup = {available=true}
        for key,value in pairs(before) do backup[key]=value end
        previousStore:save(backup)
    end
    local ok,cause = xpcall(function() adapter:write(target) end,debug.traceback)
    if not ok then
        local restored,why = xpcall(function() adapter:write(before) end,debug.traceback)
        error("graphics apply failed: " .. tostring(cause) .. (restored and "; previous values restored" or "; rollback failed: " .. tostring(why)))
    end
    return before
end
return M
