local R={};R.__index=R
function R.new(seed)return setmetatable({state=math.max(1,math.floor(seed or 1)%2147483647)},R)end
function R:next()self.state=(self.state*16807)%2147483647;return self.state/2147483647 end
function R:int(a,b)return a+math.floor(self:next()*(b-a+1))end
function R:pick(t)return t[self:int(1,#t)]end
return R
