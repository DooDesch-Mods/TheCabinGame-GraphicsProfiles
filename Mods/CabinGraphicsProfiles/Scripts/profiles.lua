local M = {}
M.groups = {
    {key="GI Quality",getter="GetGlobalIlluminationQuality",setter="SetGlobalIlluminationQuality",mapping="triangular"},
    {key="Shadow Detail",getter="GetShadowQuality",setter="SetShadowQuality",offset=2},
    {key="Reflection Detail",getter="GetReflectionQuality",setter="SetReflectionQuality",offset=1},
    {key="Effects Detail",getter="GetVisualEffectQuality",setter="SetVisualEffectQuality",offset=1},
}
M.templates = {balanced={gi=1,shadows=1,reflections=1,effects=1},performance={gi=0,shadows=0,reflections=0,effects=0}}
function M.savedIndex(group,quality)
    assert(math.type(quality)=="integer" and quality>=0 and quality<=4,"invalid engine quality")
    if group.mapping=="triangular" then
        for index=0,3 do if math.min(4,index*(index+1)//2)==quality then return index end end
        error("GI quality has no original game-option representation: " .. quality)
    end
    return quality-group.offset
end
function M.engineQuality(group,index)
    return math.max(0,math.min(4,group.mapping=="triangular" and index*(index+1)//2 or index+group.offset))
end
return M
