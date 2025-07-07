function NoteToFrequency(n)
  
  local base_a4=440
  local result = nil
  local pow = function(a,b)
    return a ^ b
  end
    
  if (n>=0)and(n<=119) then
    result = base_a4 * pow(2,(n-57)/12)
  else 
    result =-1
  end
  
  return result
end

for i = 0,119 do
  print(48000 / NoteToFrequency(i))
end


