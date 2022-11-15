local bmig = require 'bmig'
local diff = require 'diff'

function script.update(dt)
    local data = ac.accessCarPhysics()
    local dataCphys = ac.getCarPhysics(car.index)

    bmig.control(data,dataCphys)
    diff.control(data,dataCphys)
end