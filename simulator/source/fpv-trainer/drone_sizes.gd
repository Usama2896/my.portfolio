extends RefCounted
# Propeller labels are not airframe dimensions. Each preset has an explicitly
# approximate overall envelope; the user can replace it with a measured span.
const LABELS = ["2.5-inch FPV", "5-inch FPV", "7-inch FPV", "10-inch FPV", "13-inch FPV", "16–17-inch FPV"]
const SPANS = [0.16,0.30,0.42,0.60,0.78,1.02]
static func radius(span_metres: float) -> float:
	return clampf(span_metres,0.10,1.40)/2.0
