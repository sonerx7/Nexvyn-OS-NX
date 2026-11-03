-- Shared runtime audio mixer: streamed scores, limited short PCM voices, foley.
-- Sound layers and ambience beds (audio/layers, manifest "layers" / "ambience") are plain WAV files played with
-- audio.play, so they need no SDK 1.9; they are on when options.fx (Effects) is Medium or High.
local A={};A.__index=A
function A.new(options,family)
 local data=json.decode(fs.read('bundle:/audio/manifest.json'))
 return setmetatable({options=options,family=family,data=data,now=0,voices={},last={},variants={},travel=0,air=0,paused=false},A)
end
function A:track(key)
 if not self.options.music then key=nil end
 if key==self.current then return end
 audio.musicStop();self.current=key
 if key and self.data.music[key] then audio.music('bundle:/'..self.data.music[key].file);if self.paused then audio.musicPause(true) end end
end
function A:layersOn() return (tonumber(self.options.fx) or 2)>=2 and self.data.layers~=nil end
function A:layer(name,gain,v)
 local def=self.data.layers and self.data.layers[name];if not def then return end
 local n=(self.layerVariants and self.layerVariants[name] or 0)%#def.files+1
 self.layerVariants=self.layerVariants or {};self.layerVariants[name]=n
 local volume=math.max(0,math.min(1,(self.options.volume or .72)*(gain or 1)*(def.gain or .5)))
 if volume<=0 then return end
 local channel=audio.play('bundle:/'..def.files[n],volume,0)
 if channel then self.voices[#self.voices+1]={channel=channel,untilTime=self.now+(def.durations and def.durations[n] or 1)+.05} end
end
function A:ambience(key) self.ambKey=key end
function A:ambienceStop() if self.ambChannel then audio.stop(self.ambChannel);self.ambChannel=nil end;self.ambPlaying=nil end
function A:ambienceUpdate()
 local def=self.ambKey and self.data.ambience and self.data.ambience[self.ambKey]
 if self.paused or self.options.sound==false or not self:layersOn() then def=nil end
 local volume=def and math.max(0,math.min(1,(self.options.volume or .72)*(def.gain or .2))) or 0
 local want=def and volume>0 and self.ambKey or nil
 if want~=self.ambPlaying or (want and math.abs(volume-(self.ambVolume or 0))>.01) then
  self:ambienceStop()
  if want then self.ambChannel=audio.play('bundle:/'..def.file,volume,-1);self.ambPlaying=want;self.ambVolume=volume end
 end
end
function A:sfx(name,gain)
 if self.options.sound==false or self.paused then return false end
 local def=self.data.effects[name];if not def then return false end
 if self.last[name] and self.now-self.last[name]<(def.cooldown or .06) then return false end
 if self.frameVoices and self.frameVoices>=4 then return false end
 self.last[name]=self.now;self.frameVoices=(self.frameVoices or 0)+1
 local v=(self.variants[name] or 0)%#def.files+1;self.variants[name]=v
 if #self.voices>=12 then audio.stop(self.voices[1].channel);table.remove(self.voices,1) end
 local volume=math.max(0,math.min(1,(self.options.volume or .72)*(gain or 1)*(def.gain or 1)))
 if volume<=0 then return false end
 local channel=audio.play('bundle:/'..def.files[v],volume,0)
 if channel then self.voices[#self.voices+1]={channel=channel,untilTime=self.now+(def.durations and def.durations[v] or 4)+.05} end
 if channel and self:layersOn() then self:layer(name,gain) end
 return true
end
function A:update(dt)
 self.now=self.now+dt;self.dt=dt;self.frameVoices=0
 self:ambienceUpdate()
 for i=#self.voices,1,-1 do if self.voices[i].untilTime<=self.now then audio.stop(self.voices[i].channel);table.remove(self.voices,i) end end
end
function A:footsteps(p,material,playing)
 if not p or not playing then self.px=nil;self.travel=0;self.air=0;return end
 local z=p.z or p.y;local px,pz=self.px,self.pz;self.px=p.x;self.pz=z
 if not px then return end
 if p.grounded==false then self.air=self.air+(self.dt or .016);self.travel=0;return end
 if self.air>.13 then self:sfx('land',.6) end;self.air=0
 if (p.dash or 0)>0 then self.travel=0;return end
 local scale=self.family=='frost' and 1 or 32
 local delta=math.sqrt((p.x-px)^2+(z-pz)^2)*scale
 if delta>100 then self.travel=0;return end
 self.travel=self.travel+delta
 local spacing=self.family=='frost' and 38 or 46
 if self.travel>=spacing then self.travel=self.travel%spacing;self:sfx('step_'..(material or 'stone')) end
end
function A:pause(paused)
 if paused==self.paused then return end;self.paused=paused;audio.musicPause(paused)
 if paused then self:ambienceStop() end
 if paused then for _,voice in ipairs(self.voices) do audio.stop(voice.channel) end;self.voices={} end
 self.px=nil;self.travel=0
end
function A:stop()
 self:ambienceStop();self.ambKey=nil;self:track(nil);for _,voice in ipairs(self.voices) do audio.stop(voice.channel) end;self.voices={};self.px=nil
end
return A
