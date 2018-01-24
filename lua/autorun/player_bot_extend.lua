local meta = FindMetaTable("Player")
if not meta then return end

function meta:GetAiState()
    return self.AIState
end

function meta:SetAiState(index)
    self.AIState = index
end

function meta:SetTarget(target)
    self.Target = target
end

function meta:GetTarget()
    return self.Target
end