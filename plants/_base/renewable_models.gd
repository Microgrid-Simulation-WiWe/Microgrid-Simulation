class_name RenewableModels
extends RefCounted
## Wetter → Verfügbarkeit 0..1. MVP-Version, Einheiten wie im WeatherGenerator.

## Solar: ghi in W/m², t_air in °C. Der Faktor 0,83 enthält Verluste und Wechselrichter.
static func solar_factor(ghi: float, t_air: float) -> float:
	if ghi <= 0.0:
		return 0.0
	var t_cell := t_air + 0.035 * ghi
	return clampf(ghi / 1000.0 * (1.0 - 0.004 * (t_cell - 25.0)) * 0.83, 0.0, 1.0)


## Wind: wind_speed in m/s. HUB_FACTOR rechnet den niedrigen Bodenwind des Generators auf Nabenhöhe hoch.
const HUB_FACTOR := 2.5
const V_IN := 3.0
const V_RATED := 12.0
const V_OUT := 25.0
const WIND_LOSS := 0.88

static func wind_factor(wind_speed: float) -> float:
	var v := wind_speed * HUB_FACTOR
	if v < V_IN or v >= V_OUT:
		return 0.0
	if v >= V_RATED:
		return WIND_LOSS
	var vin3 := V_IN * V_IN * V_IN
	return (v * v * v - vin3) / (V_RATED * V_RATED * V_RATED - vin3) * WIND_LOSS
