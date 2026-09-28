extends RefCounted
## Port of Hose, Hydrant, Pump, Collector, Distributor and JetPipe pressure rules.
## IDs refer to original serialized Unity component IDs, retained in data/*.json.
var components: Dictionary
var ports: Dictionary = {}
var links: Dictionary = {}
var valves: Dictionary = {}
var sources: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	components = data
	for id in components:
		var c: Dictionary = components[id]
		if c.get("script", "") in ["ConnectionController", "HoseConnectionController"]:
			ports[str(id)] = c.data
		if c.get("script", "") in ["PumpController", "DistributorController"]:
			valves[str(id)] = []
			for _p in c.data.outputConnections:
				valves[str(id)].append(false)

func rid(p: Dictionary) -> String:
	return str(int(p.get("m_PathID", 0)))

func connect_ports(a: String, b: String) -> bool:
	if a == b or not ports.has(a) or not ports.has(b): return false
	if links.has(a) or links.has(b): return false
	if int(ports[a].connectionSize) != int(ports[b].connectionSize): return false
	if rid(ports[a].parentObject) == rid(ports[b].parentObject): return false
	links[a] = b
	links[b] = a
	return true

func disconnect_port(a: String) -> void:
	if links.has(a):
		var b: String = links[a]
		links.erase(a)
		links.erase(b)

func incoming(p: String, visited: Dictionary) -> float:
	if not links.has(p): return 0.0
	return pressure(links[p], visited)

func pressure(p: String, visited: Dictionary = {}) -> float:
	if not ports.has(p) or visited.has(p): return 0.0
	var seen: Dictionary = visited.duplicate()
	seen[p] = true
	var port: Dictionary = ports[p]
	var parent: String = rid(port.parentObject)
	if not components.has(parent): return 0.0
	var c: Dictionary = components[parent]
	var d: Dictionary = c.data
	match c.get("script", ""):
		"HydrantController":
			return 3.0 if sources.get(parent, false) else 0.0
		"SuctionStrainerController":
			return float(d.connectedPressure) if sources.get(parent, false) else 0.0
		"HoseController":
			var other: String = rid(d.connections[1]) if rid(d.connections[0]) == p else rid(d.connections[0])
			var loss: float = [0.0, 0.2, 0.35][int(d.hoseType)]
			return maxf(0.0, incoming(other, seen) - loss)
		"CollectorController":
			if rid(d.outputConnection) != p: return incoming(p, seen)
			var total := 0.0
			for input in d.inputConnections: total += incoming(rid(input), seen)
			return total
		"PumpController", "DistributorController":
			if rid(d.inputConnection) == p: return incoming(p, seen)
			var opened := 0
			var enabled := false
			for i in range(d.outputConnections.size()):
				if valves[parent][i]:
					opened += 1
					if rid(d.outputConnections[i]) == p: enabled = true
			if not enabled or opened == 0: return 0.0
			return incoming(rid(d.inputConnection), seen) * float(d.get("pumpMultiplier", 1.0)) / opened
		_:
			return incoming(p, seen)

func nozzle_pressure(id: String) -> float:
	return incoming(rid(components[id].data.inputConnection), {})
