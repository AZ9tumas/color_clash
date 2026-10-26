-- AnimationConstraint exposes C0 as read-only; its base frame lives on Attachment0.
-- Keep procedural poses separate from Animator-owned Transform on both joint types.
local JointUtil = {}

function JointUtil.GetC0(joint)
	if joint:IsA("Motor6D") then
		return joint.C0
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
		return joint.Attachment0.CFrame
	end
	return nil
end

function JointUtil.SetC0(joint, c0)
	if joint:IsA("Motor6D") then
		joint.C0 = c0
		return true
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
		joint.Attachment0.CFrame = c0
		return true
	end
	return false
end

return JointUtil
