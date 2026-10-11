class_name NextGoals
extends RefCounted
## Account choice unlocks derive from the existing monotonic Bestiary evaluator.
## Campaign creation freezes contract ownership; later profile changes do not
## change an already-created road graph or loadout.

const TRIALS := {"trial_army": 1, "trial_dash": 2, "trial_reaction": 3}

static func available_trials(stars := -1) -> Array:
	var total := MetaProgress.total_stars() if stars < 0 else stars
	var out := []
	for id: String in TRIALS:
		if total >= TRIALS[id]: out.append(id)
	return out

static func choice_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stars := MetaProgress.total_stars()
	for id: String in TRIALS:
		out.append({"name": CampaignCatalog.CONTRACTS[id]["name"], "progress": stars, "target": TRIALS[id], "owned": stars >= TRIALS[id], "scope": "Account unlock for new campaigns; existing roads keep their frozen choices"})
	for id: String in ["relay_lens", "ember_banner", "blade_compass"]:
		var definition: Dictionary = Relics.DEFS[id]
		out.append({"name": definition["name"], "progress": stars, "target": definition["stars"], "owned": MetaProgress.relic_owned(id), "scope": "Account relic choice; carry one · also earned by " + CampaignCatalog.CONTRACTS[definition["trial"]]["name"]})
	return out

static func suggested(realm_id := "") -> String:
	var realm := Realm.data(realm_id if realm_id != "" else Realm.current)
	var goal_kind := ""
	var progress := 0
	var target := 100
	var smallest := 100000000
	for enemy: Dictionary in realm["enemies"].values():
		var kind: String = enemy["label"]
		var kills := int(MetaProgress.bestiary.get(kind, 0))
		for threshold: int in MetaProgress.BESTIARY_STEPS:
			if kills < threshold:
				if threshold - kills < smallest:
					smallest = threshold - kills
					goal_kind = kind
					progress = kills
					target = threshold
				break
	if goal_kind != "":
		var choice := ""
		for row: Dictionary in choice_rows():
			if not row["owned"]:
				choice = " · Next choice: %s (%d/%d stars)" % [row["name"], row["progress"], row["target"]]
				break
		return "NEXT MASTERY · %s: %d/%d kills → +1 Bestiary star%s. Campaign kills bank only on success." % [goal_kind, progress, target, choice]
	return realm_goal()

static func realm_goal() -> String:
	for id: String in Realm.ORDER:
		if not MetaProgress.is_won(id):
			var i := Realm.index(id)
			var reward: String = "unlock " + Realm.data(Realm.ORDER[i + 1])["name"] if i < Realm.ORDER.size() - 1 else "complete the realm collection"
			return "REALM GOAL · Defeat %s → %s (not yet won). Classic victory or a successful campaign guardian counts." % [Realm.data(id)["enemies"]["FinalBoss"]["label"], reward]
	return "REALM GOAL · All realms conquered. Try an unlocked tactic contract or another carried relic."
