IsAbleToSetLayerPause = return_true
function SetPauseLayerPause(pause, layer, keep_sounds)
  if IsAbleToSetLayerPause() then
    if pause then
      TurboSpeed(false)
      Pause(layer, keep_sounds)
    else
      Resume(layer)
    end
  end
end