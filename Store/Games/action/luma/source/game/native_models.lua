-- SDK 1.8 model scheduler. One background import at a time; independent handles
-- keep each enemy's animation separate while the SDK shares geometry/textures.
local M={};M.__index=M
function M.new()
 return setmetatable({queue={},handles={},pending=false,closed=false,error=nil},M)
end
function M:request(path,accept)
 if self.closed then return end
 self.queue[#self.queue+1]={path=path,accept=accept}
end
function M:update()
 if self.closed or self.pending or #self.queue==0 then return end
 local job=table.remove(self.queue,1);self.pending=true
 local ok,err=pcall(g3d.loadModel,job.path,function(model,why)
  self.pending=false
  if self.closed then if model then model:free() end;return end
  if not model then self.error=tostring(why or job.path);return end
  self.handles[#self.handles+1]=model
  job.accept(model)
 end)
 if not ok then self.pending=false;self.error=tostring(err) end
end
function M:ready() return not self.pending and #self.queue==0 end
function M:close()
 if self.closed then return end;self.closed=true;self.queue={}
 for _,model in ipairs(self.handles) do model:free() end;self.handles={}
end
function M.animate(state,clip,dt,speed,loop)
 if state.clip~=clip then
  state.model:play(clip,{loop=loop~=false,speed=speed or 1,fade=.16});state.clip=clip
 end
 state.model:update(dt)
end
return M
