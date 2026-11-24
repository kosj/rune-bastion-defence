class_name DB
## Static game data v4: towers (+ mastery abilities), enemies, heroes (+ talent tree), spells, star upgrades, 8 levels.
## Design: every enemy archetype has a clear counter (swarm->artillery, armor->mage, magic-resist->physical,
## fast->barracks/slow, flying->archer/mage, sapper->ranged focus, boss->everything + spells).

const TOWER_ORDER := ["archer", "barracks", "mage", "artillery"]

const TOWERS := {
	"archer": {
		"name": "궁수 탑", "short": "궁수", "color": Color(0.45, 0.85, 0.35),
		"desc": "저렴하고 빠른 단일 공격. 공중 적 공격 가능.",
		"dmg_type": "physical", "air": true, "projectile": "arrow",
		"levels": [
			{"cost": 70, "range": 7.2, "rate": 0.70, "dmg": [4, 6], "model": "archer_1"},
			{"cost": 110, "range": 7.8, "rate": 0.60, "dmg": [8, 12], "model": "archer_2"},
			{"cost": 160, "range": 8.6, "rate": 0.50, "dmg": [13, 19], "model": "archer_3"},
		],
		"masteries": [
			{"id": "ranger", "name": "레인저 길드", "cost": 230, "desc": "화살 3발을 서로 다른 적에게 동시 발사 (군중·공중 대응)",
			 "range": 9.0, "rate": 0.50, "dmg": [13, 19], "multishot": 3, "tint": Color(0.35, 1.0, 0.45),
			 "ability": {"id": "poison", "name": "독 화살", "cost": 180, "desc": "화살이 3초 동안 적을 중독시킵니다 (초당 9, 방어 무시)"}},
			{"id": "marksman", "name": "명사수 망루", "cost": 250, "desc": "초장거리 저격. 방어력 50% 관통, 30% 확률 3배 치명타",
			 "range": 12.0, "rate": 1.0, "dmg": [32, 46], "crit": 0.30, "pierce": 0.5, "tint": Color(1.0, 0.85, 0.3),
			 "ability": {"id": "execute", "name": "처형 사격", "cost": 200, "desc": "체력 25% 이하인 적을 즉시 처치합니다 (보스 제외)"}},
		],
	},
	"barracks": {
		"name": "병영", "short": "병영", "color": Color(0.4, 0.6, 1.0),
		"desc": "병사 3명이 길을 막는다. 포병과 함께 쓰면 강력.",
		"dmg_type": "physical", "air": false, "projectile": "",
		"levels": [
			{"cost": 70, "range": 5.5, "soldier_hp": 55, "soldier_dmg": [2, 4], "soldier_armor": 0.0, "count": 3, "respawn": 10.0, "model": "barracks_1"},
			{"cost": 110, "range": 5.8, "soldier_hp": 90, "soldier_dmg": [4, 7], "soldier_armor": 0.15, "count": 3, "respawn": 10.0, "model": "barracks_2"},
			{"cost": 150, "range": 6.2, "soldier_hp": 140, "soldier_dmg": [7, 11], "soldier_armor": 0.3, "count": 3, "respawn": 9.0, "model": "barracks_3"},
		],
		"masteries": [
			{"id": "paladin", "name": "성기사단", "cost": 230, "desc": "강철 성기사 3명. 높은 방어력과 자가 치유",
			 "range": 6.4, "soldier_hp": 260, "soldier_dmg": [10, 15], "soldier_armor": 0.55, "count": 3, "respawn": 9.0, "heal": 7.0, "tint": Color(1.0, 0.85, 0.35),
			 "ability": {"id": "holy", "name": "신성한 일격", "cost": 200, "desc": "병사의 공격에 50% 마법 피해가 더해집니다 (해골 기사 특효)"}},
			{"id": "lancer", "name": "창기병 경비대", "cost": 240, "desc": "정예 창병 4명. 높은 공격력",
			 "range": 6.6, "soldier_hp": 170, "soldier_dmg": [16, 24], "soldier_armor": 0.3, "count": 4, "respawn": 8.0, "tint": Color(0.45, 0.75, 1.0),
			 "ability": {"id": "javelin", "name": "투창 세례", "cost": 220, "desc": "병사가 3초마다 사거리 6 안의 적에게 투창을 던집니다 (공중 포함, 18-28)"}},
		],
	},
	"mage": {
		"name": "마법사 탑", "short": "마법", "color": Color(0.75, 0.45, 1.0),
		"desc": "방어력을 무시하는 강한 마법 피해. 중장갑 킬러.",
		"dmg_type": "magic", "air": true, "projectile": "bolt",
		"levels": [
			{"cost": 100, "range": 6.6, "rate": 1.5, "dmg": [12, 20], "model": "mage_1"},
			{"cost": 160, "range": 7.0, "rate": 1.45, "dmg": [26, 40], "model": "mage_2"},
			{"cost": 240, "range": 7.5, "rate": 1.4, "dmg": [44, 70], "model": "mage_3"},
		],
		"masteries": [
			{"id": "arcane", "name": "비전 성소", "cost": 280, "desc": "적 4명에게 튕기는 연쇄 번개",
			 "range": 7.8, "rate": 1.5, "dmg": [46, 72], "chain": 4, "tint": Color(0.75, 0.45, 1.0),
			 "ability": {"id": "teleport", "name": "차원 이동", "cost": 220, "desc": "6초마다 번개에 맞은 적 하나를 길 뒤쪽으로 8m 되돌립니다 (보스 제외)"}},
			{"id": "frost", "name": "서리 첨탑", "cost": 260, "desc": "주변 적을 50% 둔화시키는 냉기 폭발",
			 "range": 7.6, "rate": 1.3, "dmg": [32, 48], "slow": 0.5, "splash": 2.2, "tint": Color(0.45, 0.9, 1.0),
			 "ability": {"id": "freeze", "name": "절대 영도", "cost": 180, "desc": "냉기 폭발에 맞은 적이 20% 확률로 1.5초 동안 얼어붙습니다"}},
		],
	},
	"artillery": {
		"name": "포병 요새", "short": "포병", "color": Color(1.0, 0.5, 0.3),
		"desc": "느리지만 넓은 광역 폭발. 지상 전용.",
		"dmg_type": "physical", "air": false, "projectile": "bomb",
		"levels": [
			{"cost": 125, "range": 7.6, "rate": 2.8, "dmg": [9, 16], "splash": 2.0, "model": "artillery_1"},
			{"cost": 200, "range": 8.0, "rate": 2.8, "dmg": [20, 34], "splash": 2.2, "model": "artillery_2"},
			{"cost": 300, "range": 8.6, "rate": 2.8, "dmg": [34, 56], "splash": 2.4, "model": "artillery_3"},
		],
		"masteries": [
			{"id": "bombard", "name": "드워프 대포", "cost": 300, "desc": "거대한 폭발과 불타는 화염 지대",
			 "range": 9.0, "rate": 3.2, "dmg": [60, 95], "splash": 3.2, "burn": 12.0, "tint": Color(1.0, 0.5, 0.2),
			 "ability": {"id": "shock", "name": "충격 포탄", "cost": 220, "desc": "폭발에 휘말린 지상 적을 0.8초 기절시킵니다 (보스 제외)"}},
			{"id": "cluster", "name": "집속 박격포", "cost": 280, "desc": "착탄 후 소형 폭탄 4개가 추가 폭발",
			 "range": 9.2, "rate": 2.8, "dmg": [40, 60], "splash": 2.4, "cluster": 4, "tint": Color(0.95, 0.9, 0.4),
			 "ability": {"id": "napalm", "name": "네이팜 탄두", "cost": 200, "desc": "소형 폭탄이 불길을 남겨 적을 3초 동안 태웁니다 (초당 10)"}},
		],
	},
}

const ENEMIES := {
	"goblin": {"name": "고블린 약탈자", "model": "goblin", "hp": 30, "speed": 2.4, "armor": 0.0, "mr": 0.0,
		"gold": 5, "lives": 1, "dmg": [1, 3], "atk_rate": 1.0, "scale": 1.4, "desc": "약하지만 떼로 몰려온다 → 포병"},
	"wolf": {"name": "다이어 울프", "model": "wolf", "hp": 40, "speed": 3.9, "armor": 0.0, "mr": 0.0,
		"gold": 6, "lives": 1, "dmg": [2, 4], "atk_rate": 0.8, "scale": 1.5, "desc": "매우 빠름 → 병영으로 막고 서리로 둔화"},
	"shaman": {"name": "고블린 주술사", "model": "goblin", "hp": 60, "speed": 2.0, "armor": 0.0, "mr": 0.6,
		"gold": 12, "lives": 1, "dmg": [2, 4], "atk_rate": 1.2, "scale": 1.5, "tint": Color(0.75, 0.5, 1.0),
		"heal": 14.0, "desc": "주변 적 치유, 마법 저항 → 궁수·포병"},
	"sapper": {"name": "고블린 폭탄병", "model": "sapper", "hp": 70, "speed": 2.1, "armor": 0.1, "mr": 0.0,
		"gold": 10, "lives": 1, "dmg": [0, 0], "atk_rate": 1.0, "scale": 1.45,
		"explode": 45.0, "desc": "병사에게 막히면 자폭! → 원거리로 먼저 처치"},
	"orc": {"name": "오크 돌격병", "model": "orc", "hp": 190, "speed": 1.35, "armor": 0.5, "mr": 0.0,
		"gold": 16, "lives": 2, "dmg": [6, 10], "atk_rate": 1.3, "scale": 2.2, "desc": "중장갑 (물리 50% 감소) → 마법"},
	"warchief": {"name": "오크 족장", "model": "orc", "hp": 650, "speed": 1.2, "armor": 0.6, "mr": 0.1,
		"gold": 55, "lives": 4, "dmg": [14, 22], "atk_rate": 1.4, "scale": 2.8, "tint": Color(1.0, 0.55, 0.45),
		"warcry": true, "desc": "전투 함성으로 주변 적 가속 → 최우선 처치"},
	"gargoyle": {"name": "가고일", "model": "gargoyle", "hp": 85, "speed": 2.2, "armor": 0.0, "mr": 0.25,
		"gold": 12, "lives": 1, "dmg": [0, 0], "atk_rate": 1.0, "scale": 1.6, "flying": true, "desc": "비행 - 병영·포병 무시 → 궁수"},
	"ogre": {"name": "바위 오우거", "model": "ogre", "hp": 950, "speed": 0.95, "armor": 0.25, "mr": 0.25,
		"gold": 60, "lives": 3, "dmg": [24, 34], "atk_rate": 2.0, "scale": 3.0,
		"slam": true, "desc": "거대한 체력, 내려찍기로 병사 기절"},
	"troll": {"name": "트롤 군주 그롬", "model": "troll", "hp": 4200, "speed": 0.8, "armor": 0.3, "mr": 0.3,
		"gold": 400, "lives": 10, "dmg": [35, 55], "atk_rate": 2.2, "scale": 4.2, "boss": true, "slam": true, "enrage_summon": "goblin",
		"desc": "보스 - 체력 50%에서 격노하여 고블린 소환"},
	"skeleton": {"name": "해골 병사", "model": "skeleton_knight", "hp": 42, "speed": 2.0, "armor": 0.2, "mr": 0.0,
		"gold": 4, "lives": 1, "dmg": [2, 4], "atk_rate": 1.0, "scale": 1.45, "tint": Color(0.82, 1.0, 0.86),
		"desc": "리치가 일으킨 해골 무리 → 포병·마법"},
	"skeleton_knight": {"name": "해골 기사", "model": "skeleton_knight", "hp": 300, "speed": 1.3, "armor": 0.6, "mr": -0.2,
		"gold": 24, "lives": 2, "dmg": [9, 14], "atk_rate": 1.3, "scale": 2.1, "revive": 0.5,
		"desc": "중장갑, 쓰러져도 한 번 다시 일어남 → 마법(추가 피해)으로 두 번 처치"},
	"lich": {"name": "리치 군주 모르가스", "model": "lich", "hp": 7000, "speed": 0.7, "armor": 0.25, "mr": 0.5,
		"gold": 600, "lives": 20, "dmg": [40, 60], "atk_rate": 2.0, "scale": 3.7, "boss": true,
		"summon": "skeleton", "summon_n": 4, "summon_cd": 10.0, "enrage_summon": "skeleton_knight",
		"desc": "최종 보스 - 해골을 끝없이 불러내고, 체력 50%에서 해골 기사 군단을 소환"},
}

const HEROES := {
	"kael": {
		"name": "엠버 기사 카엘", "title": "불꽃의 검사", "model": "hero", "scale": 1.95, "weapon": "w_sword",
		"portrait": "portrait_hero", "skill_icon": "skill_fire", "skill_name": "불꽃 검무",
		"desc": "근접 탱커. 적을 몸으로 막아 세우고, 주변을 불태우는 검무로 무리를 쓸어버립니다.",
		"hp": 320, "dmg": [12, 18], "armor": 0.4, "atk_rate": 0.9, "speed": 4.2, "ranged": false,
		"respawn": 14.0, "regen": 8.0, "skill_cd": 14.0, "skill_dmg": 70, "skill_radius": 3.2, "unlock": -1,
	},
	"sera": {
		"name": "별빛 마법사 세라", "title": "별의 대마법사", "model": "sera", "scale": 1.8, "weapon": "",
		"portrait": "portrait_sera", "skill_icon": "skill_star", "skill_name": "별빛 폭풍",
		"desc": "원거리 마법 딜러. 공중 적도 공격하고 방어력을 무시하는 마법탄을 쏩니다. 별빛 폭풍은 넓은 범위를 강타하고 둔화시킵니다.",
		"hp": 210, "dmg": [15, 23], "armor": 0.1, "atk_rate": 1.15, "speed": 4.0, "ranged": true, "range": 6.2,
		"respawn": 14.0, "regen": 6.0, "skill_cd": 16.0, "skill_dmg": 75, "skill_radius": 3.6, "skill_slow": 0.6,
		"unlock": 1,
	},
}
const HERO_XP := [0, 120, 320, 650, 1100]

## Persistent hero progression: experience earned in battle accumulates across regions into a rank;
## every rank gives one talent point (talents: 3 levels each).
const HERO_RANKS := [0, 250, 650, 1200, 1900, 2800, 3900, 5200, 6700, 8400, 10300, 12500]
const HERO_TALENTS := [
	{"id": "hp", "name": "강인함", "icon": "ht_hp", "desc": "최대 체력 +12% / 단계", "per": 0.12},
	{"id": "dmg", "name": "무기 숙련", "icon": "ht_dmg", "desc": "공격력 +10% / 단계", "per": 0.10},
	{"id": "skill", "name": "비전 집중", "icon": "ht_skill", "desc": "스킬 피해 +15% · 범위 +5% / 단계", "per": 0.15},
	{"id": "cd", "name": "전투 감각", "icon": "ht_cd", "desc": "스킬 재사용 -10% · 부활 -1.5초 / 단계", "per": 0.10},
]
const TALENT_MAX := 3

static func hero_rank(id: String) -> int:
	var xp := float(Game.hero_xp.get(id, 0.0))
	var r := 0
	for i in HERO_RANKS.size():
		if xp >= HERO_RANKS[i]:
			r = i + 1
	return r

## [xp into current rank, xp needed for next rank] (next = 0 at max rank)
static func hero_rank_progress(id: String) -> Array:
	var xp := float(Game.hero_xp.get(id, 0.0))
	var r := hero_rank(id)
	if r >= HERO_RANKS.size():
		return [0.0, 0.0]
	return [xp - float(HERO_RANKS[r - 1]), float(HERO_RANKS[r] - HERO_RANKS[r - 1])]

static func talent(id: String, t: String) -> int:
	return int((Game.hero_talents.get(id, {}) as Dictionary).get(t, 0))

## Talent points waiting to be spent across the heroes the player has unlocked.
static func unspent_talents() -> int:
	var n := 0
	for id in HEROES:
		if Game.hero_unlocked(id):
			n += talent_points(id)
	return n

static func talent_points(id: String) -> int:
	var used := 0
	for t in HERO_TALENTS:
		used += talent(id, t["id"])
	return maxi(hero_rank(id) - 1 - used, 0)

## Talent multiplier for a hero (1.0 + per * level).
static func talent_mult(id: String, t: String) -> float:
	for td in HERO_TALENTS:
		if td["id"] == t:
			return 1.0 + float(td["per"]) * talent(id, t)
	return 1.0

static func hero_def() -> Dictionary:
	var id: String = Game.hero_id if HEROES.has(Game.hero_id) and Game.hero_unlocked(Game.hero_id) else "kael"
	return HEROES[id]

## Lifetime achievements; each grants one bonus star for the kingdom upgrade tree.
const ACHIEVEMENTS := [
	{"id": "first_win", "name": "첫 승리", "desc": "아무 지역이나 클리어", "stat": "wins", "goal": 1, "icon": "crown"},
	{"id": "flawless", "name": "철벽 수비", "desc": "생명을 하나도 잃지 않고 클리어", "stat": "flawless", "goal": 1, "icon": "heart"},
	{"id": "slayer", "name": "학살자", "desc": "적 500마리 처치", "stat": "kills", "goal": 500, "icon": "skull"},
	{"id": "slayer2", "name": "전설의 학살자", "desc": "적 3,000마리 처치", "stat": "kills", "goal": 3000, "icon": "skull"},
	{"id": "builder", "name": "건축가", "desc": "타워 60개 건설", "stat": "towers", "goal": 60, "icon": "tower_barracks_2"},
	{"id": "master", "name": "대가의 길", "desc": "타워 전문화 8회", "stat": "masteries", "goal": 8, "icon": "m_arcane"},
	{"id": "troll", "name": "트롤 사냥꾼", "desc": "트롤 왕 처치", "stat": "boss_kills", "goal": 1, "icon": "portrait_troll"},
	{"id": "heroic", "name": "영웅의 길", "desc": "영웅 난이도로 지역 클리어", "stat": "heroic_wins", "goal": 1, "icon": "star"},
	{"id": "allstars", "name": "별의 수호자", "desc": "모든 지역 별 3개", "stat": "stars", "goal": 24, "icon": "star"},
	{"id": "meteor", "name": "하늘의 분노", "desc": "유성 낙하 25회 사용", "stat": "meteors", "goal": 25, "icon": "spell_meteor"},
	{"id": "gold", "name": "왕실 금고", "desc": "누적 골드 20,000 획득", "stat": "gold", "goal": 20000, "icon": "coin"},
	{"id": "sera", "name": "별빛의 동료", "desc": "세라와 함께 지역 클리어", "stat": "sera_wins", "goal": 1, "icon": "portrait_sera"},
	{"id": "endless15", "name": "끝없는 전쟁", "desc": "무한 모드 15웨이브 도달", "stat": "endless_wave", "goal": 15, "icon": "wave_call"},
	{"id": "endless30", "name": "불멸의 성채", "desc": "무한 모드 30웨이브 도달", "stat": "endless_wave", "goal": 30, "icon": "crown"},
	{"id": "lich", "name": "망자의 안식", "desc": "리치 군주 모르가스 처치", "stat": "lich_kills", "goal": 1, "icon": "portrait_lich"},
	{"id": "abilities", "name": "룬 장인", "desc": "타워 특수 능력 10회 습득", "stat": "abilities", "goal": 10, "icon": "a_teleport"},
]

## Procedural escalating waves for endless mode: a growing "threat budget" spent on
## an enemy pool that widens as waves go on; every 10th wave is a boss wave.
static func endless_waves(count: int, paths: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := []
	var pool := [["goblin", 1, 1.0], ["wolf", 2, 1.3], ["orc", 4, 6.0], ["shaman", 5, 2.2], ["gargoyle", 6, 2.8],
		["sapper", 7, 2.4], ["skeleton", 4, 1.4], ["skeleton_knight", 9, 8.0], ["warchief", 9, 18.0], ["ogre", 11, 26.0]]
	for n in range(1, count + 1):
		var budget := 6.0 + n * 3.0 + pow(n, 1.3) * 0.9
		var wave := []
		var delay := 0.0
		if n % 10 == 0:
			if n == 10:
				wave.append(["ogre", 1, 6.0, 0.0, 0])
				wave.append(["warchief", 1, 6.0, 2.0, 1 % maxi(paths, 1)])
			elif n == 20:
				wave.append(["ogre", 2, 7.0, 0.0, 0])
			else:
				wave.append(["troll", 1 + int((n - 30) / 30), 8.0, 0.0, 0])
			budget *= 0.5
			delay = 5.0
		var avail := []
		for e in pool:
			if n >= int(e[1]):
				avail.append(e)
		var groups := mini(2 + int(n / 6), 5)
		for g in groups:
			var e: Array = avail[rng.randi_range(maxi(0, avail.size() - 4), avail.size() - 1)] if rng.randf() < 0.6 else avail[rng.randi() % avail.size()]
			var cnt := maxi(1, int(budget / groups / float(e[2])))
			var interval := clampf(1.8 / sqrt(cnt), 0.3, 2.0) * (2.2 if float(e[2]) >= 10.0 else 1.0)
			wave.append([e[0], mini(cnt, 40), interval, delay, g % maxi(paths, 1)])
			delay += cnt * interval * 0.45 + 1.0
		out.append(wave)
	return out

static func endless_hp_scale(wave_idx: int) -> float:
	return 1.0 + wave_idx * 0.03 + pow(maxf(wave_idx - 15, 0), 1.3) * 0.015


const SPELLS := {
	"meteor": {"name": "유성 낙하", "cd": 40.0, "dmg": 90, "radius": 2.6, "count": 5},
	"reinforce": {"name": "지원군 소집", "cd": 20.0, "hp": 70, "dmg": [3, 6], "duration": 20.0, "count": 2},
}

## Kingdom-Rush style permanent upgrades bought with stars.
const UPGRADES := [
	{"id": "archer_dmg", "name": "궁수 훈련", "desc": "궁수 탑 공격력 +12%", "cost": 2, "icon": "tower_archer_1"},
	{"id": "archer_range", "name": "매의 눈", "desc": "궁수 탑 사거리 +10%", "cost": 3, "icon": "tower_archer_3"},
	{"id": "bar_hp", "name": "강철 갑옷", "desc": "병사 체력 +20%", "cost": 2, "icon": "tower_barracks_1"},
	{"id": "bar_dmg", "name": "정예 훈련", "desc": "병사 공격력 +15%, 방어력 +10%", "cost": 3, "icon": "tower_barracks_3"},
	{"id": "mage_dmg", "name": "비전 연구", "desc": "마법사 탑 공격력 +12%", "cost": 2, "icon": "tower_mage_1"},
	{"id": "mage_speed", "name": "시간 왜곡", "desc": "마법사 탑 공격 속도 +10%", "cost": 3, "icon": "tower_mage_3"},
	{"id": "art_splash", "name": "고성능 화약", "desc": "포병 폭발 범위 +15%", "cost": 2, "icon": "tower_artillery_1"},
	{"id": "art_dmg", "name": "드워프 공학", "desc": "포병 공격력 +12%", "cost": 3, "icon": "tower_artillery_3"},
	{"id": "meteor", "name": "불타는 하늘", "desc": "유성 피해 +30%, 쿨타임 -10초", "cost": 2, "icon": "spell_meteor"},
	{"id": "reinforce", "name": "왕국 민병대", "desc": "지원군 3명, 체력 +30%", "cost": 2, "icon": "spell_reinforce"},
	{"id": "hero", "name": "영웅의 가호", "desc": "영웅 체력 +20%, 부활 -4초", "cost": 3, "icon": "portrait_hero"},
	{"id": "gold", "name": "왕실 금고", "desc": "시작 골드 +60", "cost": 3, "icon": "coin"},
	{"id": "lives", "name": "성벽 보강", "desc": "생명 +5 (영웅 난이도 +2)", "cost": 3, "icon": "heart"},
	{"id": "hero_xp", "name": "영웅의 수련", "desc": "영웅 경험치 획득 +30%", "cost": 2, "icon": "ic_hero"},
	{"id": "salvage", "name": "공병대", "desc": "타워 판매 환급 60% → 80%", "cost": 2, "icon": "sell"},
	{"id": "runes", "name": "룬 각인술", "desc": "타워 특수 능력 비용 -25%", "cost": 3, "icon": "a_freeze"},
]

const LEVELS := [
	{
		"id": "greenvale", "name": "그린베일 고개", "subtitle": "왕국의 첫 관문",
		"desc": "고블린 무리가 평화로운 그린베일로 몰려옵니다.",
		"gold": 300, "lives": 20, "hp_mult": 1.0, "theme": "meadow",
		"paths": [[[-38, -13], [-27, -13], [-20, -10], [-18, -2], [-12, 4], [-4, 5], [0, -1], [2, -9], [9, -13], [16, -10], [18, -1], [22, 7], [29, 9], [36, 9]]],
		"plots_auto": 12, "hero_start": [-6, 0], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["goblin", 6, 1.2, 0.0, 0]],
			[["goblin", 10, 0.9, 0.0, 0]],
			[["goblin", 6, 1.0, 0.0, 0], ["wolf", 4, 0.8, 6.0, 0]],
			[["orc", 2, 3.0, 0.0, 0], ["goblin", 8, 0.8, 2.0, 0]],
			[["wolf", 8, 0.6, 0.0, 0], ["goblin", 6, 0.9, 4.0, 0]],
			[["orc", 4, 2.5, 0.0, 0], ["shaman", 2, 3.0, 3.0, 0], ["goblin", 8, 0.7, 5.0, 0]],
			[["goblin", 16, 0.45, 0.0, 0], ["wolf", 6, 0.6, 6.0, 0]],
			[["orc", 6, 2.0, 0.0, 0], ["shaman", 3, 2.5, 2.0, 0], ["wolf", 6, 0.6, 8.0, 0]],
			[["goblin", 18, 0.4, 0.0, 0], ["orc", 5, 1.8, 3.0, 0], ["shaman", 3, 2.0, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 6, 1.6, 2.0, 0], ["goblin", 14, 0.5, 4.0, 0], ["wolf", 8, 0.5, 10.0, 0]],
		],
	},
	{
		"id": "twinfords", "name": "쌍둥이 여울", "subtitle": "두 갈래의 침공로",
		"desc": "강을 건너 두 방향에서 적이 몰려옵니다. 하늘과 폭탄병을 조심하세요.",
		"gold": 450, "lives": 20, "hp_mult": 1.12, "theme": "river",
		"paths": [
			[[-38, -15], [-28, -15], [-20, -12], [-12, -10], [-6, -8], [0, -3], [5, 0], [12, 1], [17, -5], [24, -7], [30, -3], [37, -3]],
			[[-38, 14], [-28, 14], [-20, 11], [-12, 9], [-6, 7], [0, 3], [5, 0], [12, 1], [17, -5], [24, -7], [30, -3], [37, -3]],
		],
		"river_x": -15.0, "plots_auto": 14, "hero_start": [8, -2], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["goblin", 6, 1.0, 0.0, 0], ["goblin", 6, 1.0, 2.0, 1]],
			[["wolf", 5, 0.7, 0.0, 0], ["goblin", 8, 0.8, 1.0, 1]],
			[["gargoyle", 4, 1.5, 0.0, 0], ["goblin", 8, 0.8, 2.0, 1]],
			[["orc", 3, 2.5, 0.0, 0], ["orc", 3, 2.5, 1.0, 1], ["shaman", 2, 3.0, 4.0, 0]],
			[["gargoyle", 6, 1.2, 0.0, 1], ["wolf", 8, 0.5, 3.0, 0]],
			[["sapper", 3, 2.0, 0.0, 0], ["goblin", 10, 0.6, 0.0, 1], ["goblin", 6, 0.6, 4.0, 0]],
			[["orc", 5, 2.0, 0.0, 0], ["gargoyle", 6, 1.0, 3.0, 1], ["wolf", 6, 0.6, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 1], ["orc", 4, 2.0, 2.0, 1], ["goblin", 14, 0.5, 0.0, 0], ["sapper", 2, 2.0, 6.0, 0]],
			[["gargoyle", 10, 0.8, 0.0, 0], ["wolf", 10, 0.5, 2.0, 1], ["shaman", 3, 2.0, 4.0, 0]],
			[["orc", 7, 1.5, 0.0, 0], ["orc", 7, 1.5, 0.0, 1], ["sapper", 4, 1.5, 5.0, 1], ["gargoyle", 5, 1.0, 6.0, 1]],
			[["warchief", 2, 4.0, 0.0, 0], ["goblin", 20, 0.4, 0.0, 1], ["wolf", 10, 0.5, 6.0, 1], ["gargoyle", 8, 0.8, 8.0, 0]],
			[["warchief", 2, 3.0, 0.0, 1], ["orc", 9, 1.2, 2.0, 0], ["shaman", 4, 2.0, 4.0, 1], ["gargoyle", 10, 0.7, 6.0, 0], ["sapper", 4, 1.2, 9.0, 1]],
		],
	},
	{
		"id": "frostwind", "name": "서리바람 고개", "subtitle": "얼어붙은 길",
		"desc": "눈보라 속 늑대 무리와 바위 오우거가 고개를 넘어옵니다.",
		"gold": 500, "lives": 20, "hp_mult": 1.2, "theme": "snow",
		"paths": [[[-38, 10], [-28, 10], [-22, 4], [-22, -6], [-14, -12], [-4, -12], [0, -4], [-4, 6], [2, 12], [12, 12], [16, 4], [12, -6], [18, -13], [26, -11], [28, -2], [37, 0]]],
		"plots_auto": 14, "hero_start": [-2, 0], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["wolf", 8, 0.7, 0.0, 0]],
			[["goblin", 12, 0.6, 0.0, 0], ["wolf", 4, 0.6, 5.0, 0]],
			[["orc", 4, 2.2, 0.0, 0], ["shaman", 2, 3.0, 3.0, 0]],
			[["wolf", 14, 0.4, 0.0, 0], ["gargoyle", 4, 1.2, 4.0, 0]],
			[["ogre", 1, 1.0, 0.0, 0], ["goblin", 12, 0.5, 2.0, 0]],
			[["sapper", 4, 1.6, 0.0, 0], ["orc", 4, 2.0, 3.0, 0], ["wolf", 8, 0.5, 6.0, 0]],
			[["gargoyle", 10, 0.8, 0.0, 0], ["shaman", 3, 2.0, 2.0, 0], ["goblin", 12, 0.5, 4.0, 0]],
			[["ogre", 2, 6.0, 0.0, 0], ["wolf", 12, 0.4, 3.0, 0], ["orc", 4, 1.8, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 7, 1.4, 1.0, 0], ["sapper", 4, 1.4, 5.0, 0], ["gargoyle", 6, 0.9, 6.0, 0]],
			[["wolf", 20, 0.3, 0.0, 0], ["goblin", 16, 0.4, 3.0, 0], ["shaman", 4, 1.8, 5.0, 0]],
			[["ogre", 3, 5.0, 0.0, 0], ["orc", 8, 1.3, 2.0, 0], ["gargoyle", 10, 0.7, 6.0, 0]],
			[["warchief", 2, 4.0, 0.0, 0], ["ogre", 2, 6.0, 3.0, 0], ["wolf", 16, 0.35, 5.0, 0], ["sapper", 5, 1.2, 9.0, 0], ["gargoyle", 8, 0.8, 12.0, 0]],
		],
	},
	{
		"id": "moonwood", "name": "달빛 숲", "subtitle": "밤의 습격",
		"desc": "달빛 아래 두 갈래 숲길로 가고일과 폭탄병이 숨어듭니다.",
		"gold": 560, "lives": 20, "hp_mult": 1.3, "theme": "night",
		"paths": [
			[[-38, -15], [-26, -15], [-18, -8], [-10, -8], [-4, -2], [4, -2], [10, 4], [18, 4], [24, -2], [30, -2], [37, -2]],
			[[-16, 28], [-16, 18], [-12, 10], [-8, 4], [-4, -2], [4, -2], [10, 4], [18, 4], [24, -2], [30, -2], [37, -2]],
		],
		"plots_auto": 15, "hero_start": [2, 2], "bounds": [-30, 30, -18, 17],
		"waves": [
			[["goblin", 8, 0.8, 0.0, 0], ["goblin", 8, 0.8, 1.0, 1]],
			[["gargoyle", 6, 1.0, 0.0, 0], ["wolf", 6, 0.6, 2.0, 1]],
			[["orc", 4, 2.0, 0.0, 1], ["sapper", 3, 1.6, 2.0, 0], ["shaman", 2, 2.5, 4.0, 1]],
			[["wolf", 10, 0.45, 0.0, 0], ["wolf", 10, 0.45, 0.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["gargoyle", 8, 0.8, 2.0, 1], ["goblin", 10, 0.5, 4.0, 0]],
			[["sapper", 5, 1.2, 0.0, 1], ["orc", 6, 1.6, 2.0, 0], ["shaman", 3, 2.0, 4.0, 0]],
			[["gargoyle", 14, 0.6, 0.0, 0], ["goblin", 16, 0.4, 2.0, 1]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 5, 1.6, 1.0, 0], ["ogre", 1, 1.0, 8.0, 1], ["wolf", 8, 0.45, 10.0, 1]],
			[["sapper", 6, 1.0, 0.0, 0], ["sapper", 6, 1.0, 0.0, 1], ["gargoyle", 8, 0.8, 5.0, 0]],
			[["ogre", 2, 5.0, 0.0, 0], ["ogre", 2, 5.0, 2.0, 1], ["shaman", 5, 1.6, 4.0, 0], ["goblin", 18, 0.35, 6.0, 1]],
			[["warchief", 2, 3.0, 0.0, 1], ["orc", 10, 1.1, 2.0, 0], ["gargoyle", 12, 0.6, 6.0, 1]],
			[["wolf", 20, 0.32, 0.0, 0], ["sapper", 6, 1.0, 3.0, 1], ["ogre", 2, 7.0, 7.0, 0], ["gargoyle", 10, 0.6, 9.0, 1]],
			[["warchief", 2, 4.0, 0.0, 0], ["ogre", 2, 6.0, 3.0, 1], ["orc", 8, 1.1, 4.0, 1], ["shaman", 5, 1.5, 6.0, 0], ["gargoyle", 12, 0.6, 10.0, 0]],
		],
	},
	{
		"id": "trollgorge", "name": "트롤왕의 협곡", "subtitle": "트롤 군주의 진군",
		"desc": "황혼의 협곡. 트롤 군주 그롬이 직접 진군합니다.",
		"gold": 620, "lives": 20, "hp_mult": 1.42, "theme": "autumn",
		"paths": [[[-38, -7], [-28, -7], [-24, -15], [-14, -16], [-10, -7], [-14, 3], [-9, 12], [1, 12], [6, 3], [4, -7], [11, -14], [19, -12], [22, -3], [18, 7], [25, 13], [37, 13]]],
		"plots_auto": 16, "hero_start": [0, 4], "bounds": [-30, 30, -19, 17],
		"waves": [
			[["goblin", 10, 0.7, 0.0, 0], ["wolf", 5, 0.6, 5.0, 0]],
			[["orc", 4, 2.0, 0.0, 0], ["goblin", 10, 0.6, 2.0, 0]],
			[["gargoyle", 6, 1.0, 0.0, 0], ["wolf", 8, 0.5, 4.0, 0], ["sapper", 2, 2.0, 6.0, 0]],
			[["shaman", 4, 1.5, 0.0, 0], ["orc", 5, 1.8, 2.0, 0], ["goblin", 12, 0.5, 6.0, 0]],
			[["ogre", 1, 1.0, 0.0, 0], ["gargoyle", 8, 0.8, 2.0, 0], ["wolf", 10, 0.4, 5.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 8, 1.3, 1.0, 0], ["sapper", 4, 1.4, 5.0, 0]],
			[["goblin", 22, 0.35, 0.0, 0], ["gargoyle", 10, 0.7, 4.0, 0]],
			[["ogre", 2, 5.0, 0.0, 0], ["orc", 8, 1.2, 2.0, 0], ["wolf", 12, 0.4, 6.0, 0]],
			[["gargoyle", 12, 0.6, 0.0, 0], ["shaman", 5, 1.5, 2.0, 0], ["sapper", 5, 1.2, 6.0, 0]],
			[["warchief", 2, 3.5, 0.0, 0], ["goblin", 20, 0.4, 1.0, 0], ["wolf", 12, 0.4, 8.0, 0]],
			[["ogre", 3, 4.0, 0.0, 0], ["orc", 10, 1.1, 2.0, 0], ["shaman", 5, 1.6, 6.0, 0]],
			[["gargoyle", 16, 0.5, 0.0, 0], ["sapper", 6, 1.0, 3.0, 0], ["wolf", 16, 0.35, 6.0, 0]],
			[["warchief", 3, 3.0, 0.0, 0], ["ogre", 2, 6.0, 4.0, 0], ["orc", 12, 1.0, 6.0, 0], ["gargoyle", 10, 0.7, 10.0, 0]],
			[["troll", 1, 1.0, 6.0, 0], ["orc", 10, 1.2, 0.0, 0], ["warchief", 2, 4.0, 10.0, 0], ["goblin", 20, 0.4, 14.0, 0], ["gargoyle", 10, 0.8, 18.0, 0], ["ogre", 2, 6.0, 24.0, 0]],
		],
	},
	{
		"id": "citadel", "name": "검은 성채", "subtitle": "점령당한 트롤 요새",
		"desc": "트롤왕이 쓰러지자 망자의 군단이 그의 성채를 차지했습니다. 두 성문에서 해골 무리가 쏟아져 나옵니다.",
		"gold": 700, "lives": 20, "hp_mult": 1.3, "theme": "necro",
		"paths": [
			[[-38, 11], [-29, 11], [-23, 5], [-14, 5], [-9, 12], [-1, 12], [5, 6], [5, -2], [11, -6], [19, -6], [24, 0], [29, 6], [37, 6]],
			[[-38, -14], [-29, -14], [-21, -10], [-13, -12], [-5, -8], [0, -3], [5, -2], [11, -6], [19, -6], [24, 0], [29, 6], [37, 6]],
		],
		"plots_auto": 18, "hero_start": [4, 2], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["skeleton", 10, 0.8, 0.0, 0], ["skeleton", 8, 0.8, 3.0, 1]],
			[["goblin", 12, 0.6, 0.0, 1], ["wolf", 6, 0.6, 3.0, 0]],
			[["skeleton", 14, 0.5, 0.0, 0], ["gargoyle", 5, 1.1, 2.0, 1]],
			[["skeleton_knight", 2, 3.0, 0.0, 0], ["skeleton", 12, 0.5, 2.0, 1]],
			[["orc", 4, 1.8, 0.0, 1], ["shaman", 3, 2.0, 2.0, 1], ["skeleton", 14, 0.45, 0.0, 0]],
			[["skeleton_knight", 4, 2.4, 0.0, 0], ["sapper", 4, 1.4, 3.0, 1]],
			[["gargoyle", 10, 0.8, 0.0, 0], ["wolf", 12, 0.4, 2.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["skeleton_knight", 3, 2.2, 2.0, 1], ["skeleton", 16, 0.4, 5.0, 0]],
			[["warchief", 1, 1.0, 0.0, 1], ["orc", 6, 1.4, 1.0, 1], ["skeleton", 18, 0.35, 0.0, 0]],
			[["skeleton_knight", 6, 1.8, 0.0, 0], ["shaman", 4, 1.8, 3.0, 0], ["gargoyle", 8, 0.7, 5.0, 1]],
			[["sapper", 6, 1.0, 0.0, 0], ["sapper", 6, 1.0, 0.0, 1], ["wolf", 14, 0.35, 6.0, 0]],
			[["ogre", 2, 5.0, 0.0, 0], ["skeleton_knight", 5, 1.8, 2.0, 1], ["skeleton", 20, 0.35, 6.0, 1]],
			[["warchief", 2, 4.0, 0.0, 0], ["orc", 10, 1.1, 2.0, 1], ["gargoyle", 12, 0.6, 6.0, 0]],
			[["skeleton_knight", 8, 1.5, 0.0, 0], ["skeleton_knight", 6, 1.5, 3.0, 1], ["shaman", 5, 1.5, 6.0, 0], ["skeleton", 24, 0.3, 8.0, 1]],
			[["ogre", 3, 5.0, 0.0, 1], ["warchief", 2, 4.0, 4.0, 0], ["skeleton_knight", 8, 1.4, 6.0, 0], ["gargoyle", 12, 0.6, 10.0, 1], ["skeleton", 24, 0.3, 12.0, 0]],
		],
	},
	{
		"id": "falls", "name": "통곡의 폭포", "subtitle": "안개 낀 절벽길",
		"desc": "안개 자욱한 폭포 절벽을 따라 해골 기사단과 주술사가 몰려옵니다.",
		"gold": 780, "lives": 20, "hp_mult": 1.36, "theme": "ruins",
		"paths": [
			[[-38, 1], [-29, 1], [-24, -6], [-16, -7], [-11, 0], [-12, 8], [-4, 12], [4, 9], [7, 1], [14, -4], [22, -3], [26, 5], [31, 9], [37, 9]],
			[[3, -30], [3, -21], [7, -14], [10, -8], [14, -4], [22, -3], [26, 5], [31, 9], [37, 9]],
		],
		"plots_auto": 16, "hero_start": [8, 0], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["skeleton", 12, 0.7, 0.0, 0], ["goblin", 12, 0.6, 2.0, 1]],
			[["wolf", 10, 0.5, 0.0, 1], ["shaman", 3, 2.0, 2.0, 0], ["skeleton", 10, 0.6, 4.0, 0]],
			[["skeleton_knight", 3, 2.5, 0.0, 0], ["gargoyle", 6, 1.0, 2.0, 1]],
			[["orc", 5, 1.8, 0.0, 1], ["sapper", 4, 1.4, 3.0, 0], ["skeleton", 14, 0.5, 4.0, 1]],
			[["gargoyle", 12, 0.7, 0.0, 0], ["wolf", 12, 0.4, 3.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["skeleton_knight", 4, 2.0, 2.0, 1], ["shaman", 4, 1.8, 4.0, 0]],
			[["skeleton", 16, 0.45, 0.0, 0], ["skeleton", 16, 0.45, 2.0, 1]],
			[["warchief", 1, 1.0, 0.0, 1], ["orc", 8, 1.3, 1.0, 1], ["sapper", 6, 1.0, 4.0, 0]],
			[["skeleton_knight", 7, 1.6, 0.0, 0], ["gargoyle", 10, 0.7, 3.0, 1], ["shaman", 4, 1.6, 6.0, 0]],
			[["ogre", 2, 5.0, 0.0, 1], ["wolf", 16, 0.35, 2.0, 0], ["skeleton", 20, 0.35, 6.0, 1]],
			[["sapper", 8, 0.9, 0.0, 0], ["skeleton_knight", 6, 1.6, 3.0, 1], ["gargoyle", 12, 0.6, 6.0, 0]],
			[["warchief", 2, 4.0, 0.0, 0], ["orc", 9, 1.2, 2.0, 0], ["shaman", 4, 1.5, 4.0, 1], ["skeleton", 20, 0.35, 6.0, 1]],
			[["ogre", 3, 4.5, 0.0, 0], ["skeleton_knight", 8, 1.4, 3.0, 1], ["gargoyle", 14, 0.55, 8.0, 0]],
			[["skeleton_knight", 10, 1.3, 0.0, 0], ["skeleton_knight", 8, 1.3, 2.0, 1], ["wolf", 20, 0.3, 6.0, 0], ["sapper", 6, 1.0, 9.0, 1]],
			[["warchief", 2, 3.0, 0.0, 1], ["ogre", 2, 5.0, 2.0, 0], ["skeleton_knight", 8, 1.3, 5.0, 0], ["gargoyle", 12, 0.6, 8.0, 1], ["skeleton", 24, 0.32, 10.0, 0]],
		],
	},
	{
		"id": "temple", "name": "망자의 신전", "subtitle": "리치 군주의 왕좌",
		"desc": "해안의 고대 신전에서 모든 망자의 근원, 리치 군주 모르가스가 깨어났습니다. 왕국의 운명을 건 최후의 결전!",
		"gold": 880, "lives": 20, "hp_mult": 1.42, "theme": "swamp",
		"paths": [
			[[-38, -12], [-29, -12], [-23, -5], [-24, 5], [-17, 12], [-8, 11], [-4, 3], [-9, -5], [-4, -13], [6, -13], [11, -6], [8, 3], [13, 11], [21, 11], [26, 3], [31, -2], [37, -2]],
			[[-8, 30], [-8, 21], [-9, 16], [-8, 11], [-4, 3], [-9, -5], [-4, -13], [6, -13], [11, -6], [8, 3], [13, 11], [21, 11], [26, 3], [31, -2], [37, -2]],
		],
		"plots_auto": 17, "hero_start": [-2, 0], "bounds": [-30, 30, -19, 17],
		"waves": [
			[["skeleton", 14, 0.6, 0.0, 0], ["skeleton", 10, 0.6, 3.0, 1]],
			[["skeleton_knight", 3, 2.4, 0.0, 0], ["wolf", 10, 0.5, 2.0, 1]],
			[["gargoyle", 10, 0.8, 0.0, 1], ["shaman", 4, 1.8, 2.0, 0], ["goblin", 16, 0.4, 4.0, 0]],
			[["orc", 6, 1.6, 0.0, 0], ["sapper", 5, 1.2, 3.0, 1], ["skeleton", 16, 0.4, 5.0, 1]],
			[["ogre", 1, 1.0, 0.0, 1], ["skeleton_knight", 5, 1.8, 2.0, 0], ["gargoyle", 8, 0.8, 5.0, 0]],
			[["skeleton", 20, 0.36, 0.0, 0], ["wolf", 14, 0.4, 3.0, 1], ["shaman", 4, 1.6, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 8, 1.2, 1.0, 0], ["skeleton_knight", 5, 1.8, 3.0, 1]],
			[["gargoyle", 16, 0.5, 0.0, 0], ["sapper", 8, 0.9, 3.0, 1], ["skeleton", 20, 0.35, 6.0, 1]],
			[["ogre", 2, 5.0, 0.0, 0], ["skeleton_knight", 8, 1.5, 2.0, 1], ["shaman", 5, 1.5, 5.0, 0]],
			[["warchief", 2, 4.0, 0.0, 1], ["orc", 10, 1.1, 2.0, 1], ["wolf", 18, 0.32, 5.0, 0], ["gargoyle", 10, 0.6, 8.0, 0]],
			[["skeleton_knight", 9, 1.4, 0.0, 0], ["skeleton", 22, 0.34, 2.0, 1], ["sapper", 6, 1.0, 6.0, 0]],
			[["ogre", 3, 4.5, 0.0, 1], ["gargoyle", 16, 0.5, 2.0, 0], ["shaman", 6, 1.4, 5.0, 1]],
			[["warchief", 3, 3.0, 0.0, 0], ["skeleton_knight", 10, 1.3, 2.0, 1], ["orc", 12, 1.0, 6.0, 0]],
			[["ogre", 3, 4.5, 0.0, 0], ["skeleton_knight", 9, 1.3, 2.0, 1], ["gargoyle", 14, 0.55, 6.0, 1], ["skeleton", 24, 0.32, 8.0, 0]],
			[["warchief", 3, 3.0, 0.0, 1], ["ogre", 3, 4.5, 2.0, 0], ["skeleton_knight", 12, 1.2, 4.0, 0], ["sapper", 8, 0.9, 8.0, 1], ["wolf", 20, 0.3, 10.0, 0]],
			[["lich", 1, 1.0, 8.0, 0], ["skeleton_knight", 8, 1.5, 0.0, 0], ["skeleton", 24, 0.35, 0.0, 1], ["warchief", 2, 4.0, 14.0, 1], ["gargoyle", 12, 0.6, 18.0, 0], ["ogre", 2, 6.0, 24.0, 1]],
		],
	},
]

static func up(id: String) -> bool:
	return Game.upgrades.get(id, false)

## Final tower stats after mastery and star upgrades.
static func tower_stats(type: String, level: int, mastery: String) -> Dictionary:
	var t: Dictionary = TOWERS[type]
	var d: Dictionary
	if mastery != "":
		d = (t["levels"][2] as Dictionary).duplicate()
		d.merge(mastery_def(type, mastery), true)
	else:
		d = (t["levels"][clampi(level - 1, 0, 2)] as Dictionary).duplicate()
	var dm := 1.0
	match type:
		"archer":
			if up("archer_dmg"): dm = 1.12
			if up("archer_range"): d["range"] = d["range"] * 1.1
		"mage":
			if up("mage_dmg"): dm = 1.12
			if up("mage_speed"): d["rate"] = d["rate"] / 1.1
		"artillery":
			if up("art_dmg"): dm = 1.12
			if up("art_splash"): d["splash"] = d["splash"] * 1.15
		"barracks":
			if up("bar_hp"): d["soldier_hp"] = d["soldier_hp"] * 1.2
			if up("bar_dmg"):
				d["soldier_dmg"] = [d["soldier_dmg"][0] * 1.15, d["soldier_dmg"][1] * 1.15]
				d["soldier_armor"] = minf(d["soldier_armor"] + 0.1, 0.8)
	if d.has("dmg"):
		d["dmg"] = [d["dmg"][0] * dm, d["dmg"][1] * dm]
	return d

static func ability_def(type: String, mastery: String) -> Dictionary:
	return mastery_def(type, mastery).get("ability", {})

static func ability_cost(type: String, mastery: String) -> int:
	var c := int(ability_def(type, mastery).get("cost", 0))
	return int(round(c * 0.75)) if up("runes") else c

static func mastery_def(type: String, mastery: String) -> Dictionary:
	for m in TOWERS[type]["masteries"]:
		if m["id"] == mastery:
			return m
	return {}

static func total_stars() -> int:
	var s := 0
	for v in Game.stars:
		s += int(v)
	for h in Game.heroic:
		if h:
			s += 1
	return s + Game.achievement_count()

## Most stars a player can ever collect (3 per region + heroic bonus per region + one per achievement).
static func max_stars() -> int:
	return LEVELS.size() * 4 + ACHIEVEMENTS.size()

static func spent_stars() -> int:
	var s := 0
	for u in UPGRADES:
		if Game.upgrades.get(u["id"], false):
			s += int(u["cost"])
	return s
