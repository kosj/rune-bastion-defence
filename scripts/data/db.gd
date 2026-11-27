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
		"gold": 6, "lives": 1, "dmg": [2, 4], "atk_rate": 0.8, "scale": 1.5, "anim_k": 0.42, "desc": "매우 빠름 → 병영으로 막고 서리로 둔화"},
	"shaman": {"name": "고블린 주술사", "model": "goblin", "hp": 60, "speed": 2.0, "armor": 0.0, "mr": 0.6,
		"gold": 10, "lives": 1, "dmg": [2, 4], "atk_rate": 1.2, "scale": 1.5, "tint": Color(0.75, 0.5, 1.0),
		"heal": 14.0, "desc": "주변 적 치유, 마법 저항 → 궁수·포병"},
	"sapper": {"name": "고블린 폭탄병", "model": "sapper", "hp": 70, "speed": 2.1, "armor": 0.1, "mr": 0.0,
		"gold": 10, "lives": 1, "dmg": [0, 0], "atk_rate": 1.0, "scale": 1.45,
		"explode": 45.0, "desc": "병사에게 막히면 자폭! → 원거리로 먼저 처치"},
	"orc": {"name": "오크 돌격병", "model": "orc", "hp": 190, "speed": 1.35, "armor": 0.5, "mr": 0.0,
		"gold": 18, "lives": 2, "dmg": [6, 10], "atk_rate": 1.3, "scale": 2.2, "desc": "중장갑 (물리 50% 감소) → 마법"},
	"warchief": {"name": "오크 족장", "model": "orc", "hp": 650, "speed": 1.2, "armor": 0.6, "mr": 0.1,
		"gold": 55, "lives": 4, "dmg": [14, 22], "atk_rate": 1.4, "scale": 2.8, "tint": Color(1.0, 0.55, 0.45),
		"warcry": true, "desc": "전투 함성으로 주변 적 가속 → 최우선 처치"},
	"gargoyle": {"name": "가고일", "model": "gargoyle", "hp": 85, "speed": 2.2, "armor": 0.0, "mr": 0.25,
		"gold": 11, "lives": 1, "dmg": [0, 0], "atk_rate": 1.0, "scale": 1.6, "flying": true, "desc": "비행 - 병영·포병 무시 → 궁수"},
	"ogre": {"name": "바위 오우거", "model": "ogre", "hp": 950, "speed": 0.95, "armor": 0.25, "mr": 0.25,
		"gold": 62, "lives": 3, "dmg": [24, 34], "atk_rate": 2.0, "scale": 3.0,
		"slam": true, "desc": "거대한 체력, 내려찍기로 병사 기절"},
	"spear": {"name": "고블린 투창병", "model": "goblin", "hp": 55, "speed": 2.1, "armor": 0.0, "mr": 0.0,
		"gold": 8, "lives": 1, "dmg": [2, 4], "atk_rate": 1.0, "scale": 1.4, "tint": Color(1.0, 0.7, 0.42),
		"ranged": {"range": 4.5, "dmg": [5, 8], "rate": 1.8},
		"desc": "멈춰 서서 병사에게 투창을 던짐 → 병사를 붙여 막거나 궁수로 먼저 처치"},
	"rogue": {"name": "그림자 도적", "model": "goblin", "hp": 75, "speed": 2.6, "armor": 0.1, "mr": 0.2,
		"gold": 9, "lives": 1, "dmg": [3, 6], "atk_rate": 0.9, "scale": 1.45, "tint": Color(0.4, 0.33, 0.68),
		"stealth": true,
		"desc": "은신 - 궁수·포병이 보지 못함. 피해를 입거나 병사에게 막히면 드러남 → 마법사·병영"},
	"shield": {"name": "오크 방패병", "model": "orc", "hp": 280, "speed": 1.25, "armor": 0.45, "mr": 0.1,
		"gold": 22, "lives": 2, "dmg": [5, 9], "atk_rate": 1.3, "scale": 2.25, "tint": Color(0.48, 0.62, 1.0),
		"aura": 0.3, "aura_r": 3.0,
		"desc": "방패 진형 - 주변 적의 방어력 +30% → 마법으로 먼저 처치"},
	"troll": {"name": "트롤 군주 그롬", "model": "troll", "hp": 4200, "speed": 0.8, "armor": 0.3, "mr": 0.3,
		"gold": 400, "lives": 10, "dmg": [35, 55], "atk_rate": 2.2, "scale": 4.2, "boss": true, "slam": true, "enrage_summon": "goblin", "title": "협곡을 짓밟는 자",
		"desc": "보스 - 체력 50%에서 격노하여 고블린 소환"},
	"skeleton": {"name": "해골 병사", "model": "skeleton_knight", "hp": 42, "speed": 2.0, "armor": 0.2, "mr": 0.0,
		"gold": 5, "lives": 1, "dmg": [2, 4], "atk_rate": 1.0, "scale": 1.45, "tint": Color(0.82, 1.0, 0.86),
		"desc": "리치가 일으킨 해골 무리 → 포병·마법"},
	"skeleton_knight": {"name": "해골 기사", "model": "skeleton_knight", "hp": 300, "speed": 1.3, "armor": 0.6, "mr": -0.2,
		"gold": 26, "lives": 2, "dmg": [9, 14], "atk_rate": 1.3, "scale": 2.1, "revive": 0.5,
		"desc": "중장갑, 쓰러져도 한 번 다시 일어남 → 마법(추가 피해)으로 두 번 처치"},
	"lich": {"title": "죽음을 부리는 자", "name": "리치 군주 모르가스", "model": "lich", "hp": 7000, "speed": 0.7, "armor": 0.25, "mr": 0.5,
		"gold": 600, "lives": 20, "dmg": [40, 60], "atk_rate": 2.0, "scale": 3.7, "boss": true,
		"summon": "skeleton", "summon_n": 4, "summon_cd": 10.0, "enrage_summon": "skeleton_knight",
		"desc": "보스 - 해골을 끝없이 불러내고, 체력 50%에서 해골 기사 군단을 소환"},
	"ogre_king": {"title": "산을 부수는 자", "name": "오우거 왕 고르막", "model": "ogre", "hp": 7000, "speed": 0.72, "armor": 0.4, "mr": 0.25,
		"gold": 700, "lives": 20, "dmg": [50, 75], "atk_rate": 2.4, "scale": 4.6, "boss": true, "slam": true, "warcry": true,
		"tint": Color(1.0, 0.52, 0.45), "enrage_summon": "ogre", "enrage_n": 2, "enrage_text": "오우거 친위대가 몰려옵니다",
		"desc": "최종 보스 - 내려찍기로 병사 기절, 전투 함성으로 주변 적 가속, 체력 50%에서 오우거 친위대 소환"},
}

## Short scenes shown on the first visit to each region (and after the final victory).
## Speakers: "hero" (the chosen hero), "captain" (the castle guard captain) or a boss enemy id.
const STORY := {
	"greenvale": [["captain", "고블린 무리가 그린베일 고개로 몰려옵니다! 왕국의 첫 관문을 지켜야 합니다."],
		["hero", "걱정 마세요, 브란 대장님. 한 놈도 성문에 닿지 못하게 하겠습니다."]],
	"twinfords": [["captain", "적이 강을 사이에 두고 두 갈래로 건너옵니다. 하늘에서는 가고일까지 내려온다는 보고입니다."],
		["hero", "다리 두 곳을 모두 지켜야겠군요. 궁수를 넉넉히 세우죠."]],
	"frostwind": [["captain", "서리바람 고개의 눈보라 속에서 늑대 울음이 들립니다."],
		["hero", "늑대는 빠릅니다. 병영으로 길을 막고 서리 마법으로 발을 묶어요."]],
	"moonwood": [["hero", "달빛 숲이 이상하게 조용하네요..."],
		["captain", "폭탄병이 숲길에 숨어들었습니다! 병사들과 붙기 전에 처리하십시오."]],
	"trollgorge": [["troll", "작은 것들! 그롬이 너희 성벽을 돌가루로 만들어 주마!"],
		["hero", "트롤 군주 그롬... 이 협곡에서 끝을 내겠습니다."]],
	"citadel": [["captain", "트롤은 쓰러졌지만, 검은 성채에서 망자들이 일어나고 있습니다."],
		["hero", "누군가 죽은 자를 깨우고 있어요. 그 배후를 찾아야 합니다."]],
	"falls": [["captain", "폭포 아래로 해골 기사들이 행군합니다. 쓰러뜨려도 다시 일어난다더군요."],
		["hero", "마법이 잘 통할 거예요. 두 번 쓰러뜨리면 됩니다."]],
	"temple": [["lich", "산 자들이여, 나의 신전에 잘 왔다. 곧 너희도 내 군대의 일부가 되리라."],
		["hero", "모르가스, 당신의 군대는 여기서 끝납니다!"]],
	"harbor": [["captain", "큰일입니다! 리치가 쓰러진 틈을 타 오우거 군대가 배를 타고 남쪽 항구에 상륙하고 있습니다!"],
		["hero", "항구가 뚫리면 왕도까지 막을 곳이 없어요. 여기서 막아야 합니다."]],
	"capital": [["ogre_king", "리치는 약했다. 이 땅의 왕좌는 이제 고르막의 것이다!"],
		["captain", "왕도의 마지막 방어선입니다. 모든 병력을 성문 앞에 모았습니다!"],
		["hero", "왕국을 지킬 마지막 싸움입니다. 끝까지 버팁시다!"]],
	"epilogue": [["captain", "오우거 왕이 쓰러졌습니다! 왕국이... 살아남았습니다!"],
		["hero", "모두가 함께 싸운 덕분이에요. 그래도 성벽은 계속 지켜야겠죠."],
		["captain", "무한 모드의 고대 열주 터에서 남은 무리가 계속 몰려온다고 합니다. 언제든 다시 불러 주십시오!"]],
}
const CAPTAIN := {"name": "경비대장 브란", "portrait": "portrait_footman"}

const HEROES := {
	"kael": {
		"name": "엠버 기사 카엘", "title": "불꽃의 검사", "model": "hero", "scale": 1.95, "weapon": "w_sword",
		"portrait": "portrait_hero", "skill_icon": "skill_fire", "skill_name": "불꽃 검무",
		"desc": "근접 탱커. 적을 몸으로 막아 세우고, 주변을 불태우는 검무로 무리를 쓸어버립니다.",
		"hp": 320, "dmg": [12, 18], "armor": 0.4, "atk_rate": 0.9, "speed": 4.2, "ranged": false,
		"respawn": 14.0, "regen": 8.0, "skill_cd": 14.0, "skill_dmg": 70, "skill_radius": 3.2, "unlock": -1,
		"skill2": {"id": "charge", "icon": "skill_charge", "name": "화염 돌진", "cd": 18.0, "dmg": 55, "stun": 1.5,
			"reach": 7.0, "voice": "kael_move", "desc": "적이 몰린 곳으로 돌진해 지나는 길의 적에게 피해를 주고 기절시킵니다."},
	},
	"sera": {
		"name": "별빛 마법사 세라", "title": "별의 대마법사", "model": "sera", "scale": 1.8, "weapon": "",
		"portrait": "portrait_sera", "skill_icon": "skill_star", "skill_name": "별빛 폭풍",
		"desc": "원거리 마법 딜러. 공중 적도 공격하고 방어력을 무시하는 마법탄을 쏩니다. 별빛 폭풍은 넓은 범위를 강타하고 둔화시킵니다.",
		"hp": 210, "dmg": [15, 23], "armor": 0.1, "atk_rate": 1.15, "speed": 4.0, "ranged": true, "range": 6.2,
		"respawn": 14.0, "regen": 6.0, "skill_cd": 16.0, "skill_dmg": 75, "skill_radius": 3.6, "skill_slow": 0.6,
		"unlock": 1,
		"skill2": {"id": "ward", "icon": "skill_ward", "name": "별빛 결계", "cd": 22.0, "dmg": 16, "time": 5.0, "slow": 0.5,
			"radius": 3.0, "voice": "sera_select", "desc": "5초 동안 결계를 펼쳐 안에 든 적을 느리게 하고 계속 마법 피해를 줍니다."},
	},
	"ren": {
		"name": "숲의 사수 렌", "title": "바람의 명궁", "model": "ranger", "scale": 1.85, "weapon": "",
		"portrait": "portrait_ranger", "skill_icon": "skill_arrows", "skill_name": "화살비",
		"desc": "원거리 물리 딜러. 빠르게 쏘는 화살이 방어력을 30% 꿰뚫고 공중 적도 맞힙니다. 화살비는 적이 가장 많은 곳에 화살 16발을 쏟아부어 맞은 적을 둔화시킵니다.",
		"hp": 230, "dmg": [10, 15], "armor": 0.15, "atk_rate": 0.72, "speed": 4.5, "ranged": true, "range": 6.8,
		"projectile": "arrow", "pierce": 0.3,
		"respawn": 13.0, "regen": 6.0, "skill_cd": 15.0, "skill_dmg": 70, "skill_radius": 3.4, "skill_slow": 0.65,
		"unlock": 3,
		"skill2": {"id": "pierce", "icon": "skill_pierce", "name": "꿰뚫는 화살", "cd": 16.0, "dmg": 120, "length": 14.0,
			"voice": "ren_select", "desc": "일직선으로 날아가며 맞는 적 모두에게 방어를 무시하는 큰 피해를 줍니다."},
	},
}
const HERO_XP := [0, 120, 320, 650, 1100]
## The hero's second skill opens at this battle level (the level resets every battle).
const SKILL2_LEVEL := 3

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
	{"id": "allstars", "name": "별의 수호자", "desc": "모든 지역 별 3개", "stat": "stars", "goal": 30, "icon": "star"},
	{"id": "meteor", "name": "하늘의 분노", "desc": "유성 낙하 25회 사용", "stat": "meteors", "goal": 25, "icon": "spell_meteor"},
	{"id": "gold", "name": "왕실 금고", "desc": "누적 골드 20,000 획득", "stat": "gold", "goal": 20000, "icon": "coin"},
	{"id": "sera", "name": "별빛의 동료", "desc": "세라와 함께 지역 클리어", "stat": "sera_wins", "goal": 1, "icon": "portrait_sera"},
	{"id": "ogre_king", "name": "왕도의 수호자", "desc": "오우거 왕 고르막 처치", "stat": "ogre_king_kills", "goal": 1, "icon": "crown"},
	{"id": "ren", "name": "바람의 동료", "desc": "렌과 함께 지역 클리어", "stat": "ren_wins", "goal": 1, "icon": "portrait_ranger"},
	{"id": "iron", "name": "강철 의지", "desc": "철인 도전 1회 성공", "stat": "iron_clears", "goal": 1, "icon": "skull"},
	{"id": "iron_all", "name": "철인 군주", "desc": "모든 지역 철인 도전 성공", "stat": "iron_clears", "goal": 10, "icon": "crown"},
	{"id": "endless15", "name": "끝없는 전쟁", "desc": "무한 모드 15웨이브 도달", "stat": "endless_wave", "goal": 15, "icon": "wave_call"},
	{"id": "endless30", "name": "불멸의 성채", "desc": "무한 모드 30웨이브 도달", "stat": "endless_wave", "goal": 30, "icon": "crown"},
	{"id": "lich", "name": "망자의 안식", "desc": "리치 군주 모르가스 처치", "stat": "lich_kills", "goal": 1, "icon": "portrait_lich"},
	{"id": "abilities", "name": "룬 장인", "desc": "타워 특수 능력 10회 습득", "stat": "abilities", "goal": 10, "icon": "a_teleport"},
	{"id": "daily1", "name": "오늘의 용사", "desc": "오늘의 도전 첫 성공", "stat": "daily_wins", "goal": 1, "icon": "ic_daily"},
	{"id": "daily7", "name": "한 주의 수호자", "desc": "오늘의 도전 7회 성공", "stat": "daily_wins", "goal": 7, "icon": "ic_daily"},
	{"id": "streak3", "name": "꾸준한 방패", "desc": "오늘의 도전 3일 연속 성공", "stat": "daily_streak_best", "goal": 3, "icon": "ic_daily"},
]

## Procedural escalating waves for endless mode: a growing "threat budget" spent on
## an enemy pool that widens as waves go on; every 10th wave is a boss wave.
static func endless_waves(count: int, paths: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := []
	var pool := [["goblin", 1, 1.0], ["wolf", 2, 1.3], ["spear", 3, 2.0], ["orc", 4, 6.0], ["shaman", 5, 2.2], ["gargoyle", 6, 2.8],
		["rogue", 6, 2.6], ["sapper", 7, 2.4], ["skeleton", 4, 1.4], ["skeleton_knight", 9, 8.0], ["warchief", 9, 18.0],
		["shield", 10, 9.0], ["ogre", 11, 26.0]]
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


## Daily challenge: one region the player has cleared and two twists, the same for everyone on a
## given day (seeded by the date). The first win of the day gives hero experience and counts toward
## the streak and the daily achievements.
const DAILY_MODS := {
	"swift": {"name": "질주", "desc": "적 이동 속도 +25%", "icon": "speed2"},
	"armored": {"name": "강철 군단", "desc": "적 방어력 +20%", "icon": "st_armor"},
	"thrifty": {"name": "빈 금고", "desc": "시작 골드 -30%", "icon": "coin"},
	"glass": {"name": "무너진 성벽", "desc": "생명 10", "icon": "heart"},
	"no_hero": {"name": "영웅 부재", "desc": "영웅 없이 싸웁니다", "icon": "ic_hero"},
	"no_spells": {"name": "고요한 하늘", "desc": "주문을 쓸 수 없습니다", "icon": "spell_meteor"},
	"horde": {"name": "대군세", "desc": "적 수 +25%", "icon": "skull"},
	"no_barracks": {"name": "병영 금지", "desc": "병영을 지을 수 없습니다", "icon": "tower_barracks_1"},
	"no_mage": {"name": "마법 봉인", "desc": "마법사 탑을 지을 수 없습니다", "icon": "tower_mage_1"},
}
## Pairs too harsh together (the region could become unwinnable).
const DAILY_CLASH := [["no_barracks", "no_mage"], ["glass", "horde"], ["no_hero", "no_spells"]]
const DAILY_XP := 300

## Today's challenge for a day number (days since 1970 in local time): {"level", "mods"}.
static func daily_for(day: int, cleared: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 17
	var pool: Array = cleared.duplicate()
	if pool.size() > 1:
		pool.erase(0)  # the tutorial only while it is all there is
	if pool.is_empty():
		pool = [0]
	var lv: int = pool[rng.randi() % pool.size()]
	var keys: Array = DAILY_MODS.keys()
	var mods: Array = []
	var guard := 0
	while mods.size() < 2 and guard < 50:
		guard += 1
		var m: String = keys[rng.randi() % keys.size()]
		if m in mods:
			continue
		var ok := true
		for c in DAILY_CLASH:
			if m in c and mods.size() > 0 and (mods[0] in c):
				ok = false
		if ok:
			mods.append(m)
	return {"level": lv, "mods": mods}

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
		"gold": 340, "lives": 20, "hp_mult": 0.79, "theme": "meadow",
		"paths": [[[-38, -13], [-27, -13], [-20, -10], [-18, -2], [-12, 4], [-4, 5], [0, -1], [2, -9], [9, -13], [16, -10], [18, -1], [22, 7], [29, 9], [36, 9]]],
		"plots_auto": 12, "hero_start": [-6, 0], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["goblin", 9, 0.75, 0.0, 0]],
			[["goblin", 12, 0.74, 0.0, 0]],
			[["goblin", 8, 0.71, 0.0, 0], ["wolf", 5, 0.6, 6.0, 0]],
			[["orc", 2, 3.0, 0.0, 0], ["goblin", 3, 1.28, 2.0, 0]],
			[["wolf", 8, 0.6, 0.0, 0], ["goblin", 6, 0.9, 4.0, 0]],
			[["orc", 2, 4.0, 0.0, 0], ["shaman", 3, 1.5, 3.0, 0], ["goblin", 4, 1.12, 5.0, 0]],
			[["goblin", 22, 0.31, 0.0, 0], ["wolf", 8, 0.4, 6.0, 0]],
			[["orc", 4, 2.93, 0.0, 0], ["shaman", 2, 2.5, 2.0, 0], ["wolf", 3, 1.12, 8.0, 0]],
			[["goblin", 12, 0.57, 0.0, 0], ["orc", 4, 2.0, 3.0, 0], ["shaman", 3, 2.0, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 4, 2.4, 2.0, 0], ["goblin", 8, 0.77, 4.0, 0], ["wolf", 5, 0.75, 10.0, 0]],
		],
	},
	{
		"id": "twinfords", "name": "쌍둥이 여울", "subtitle": "두 갈래의 침공로",
		"desc": "강을 건너 두 방향에서 적이 몰려옵니다. 하늘과 폭탄병을 조심하세요.",
		"gold": 450, "lives": 20, "hp_mult": 0.97, "theme": "river",
		"paths": [
			[[-38, -15], [-28, -15], [-20, -12], [-12, -10], [-6, -8], [0, -3], [5, 0], [12, 1], [17, -5], [24, -7], [30, -3], [37, -3]],
			[[-38, 14], [-28, 14], [-20, 11], [-12, 9], [-6, 7], [0, 3], [5, 0], [12, 1], [17, -5], [24, -7], [30, -3], [37, -3]],
		],
		"river_x": -15.0, "plots_auto": 14, "hero_start": [8, -2], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["goblin", 7, 0.83, 0.0, 0], ["goblin", 8, 0.71, 2.0, 1]],
			[["wolf", 6, 0.56, 0.0, 0], ["goblin", 9, 0.7, 1.0, 1]],
			[["gargoyle", 4, 1.5, 0.0, 0], ["spear", 4, 1.6, 2.0, 1]],
			[["orc", 2, 4.0, 0.0, 0], ["orc", 2, 4.0, 1.0, 1], ["shaman", 2, 3.0, 4.0, 0]],
			[["gargoyle", 5, 1.5, 0.0, 1], ["wolf", 5, 0.8, 3.0, 0]],
			[["sapper", 5, 1.0, 0.0, 0], ["goblin", 17, 0.34, 0.0, 1], ["goblin", 10, 0.33, 4.0, 0]],
			[["orc", 4, 2.67, 0.0, 0], ["gargoyle", 5, 1.25, 3.0, 1], ["wolf", 7, 0.5, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 1], ["orc", 2, 3.2, 2.0, 1], ["spear", 5, 1.2, 0.0, 0], ["sapper", 2, 2.0, 6.0, 0]],
			[["gargoyle", 10, 0.8, 0.0, 0], ["wolf", 9, 0.56, 2.0, 1], ["shaman", 3, 2.0, 4.0, 0]],
			[["orc", 5, 2.25, 0.0, 0], ["orc", 5, 2.25, 0.0, 1], ["sapper", 3, 2.25, 5.0, 1], ["gargoyle", 5, 1.0, 6.0, 1]],
			[["warchief", 2, 4.0, 0.0, 0], ["goblin", 19, 0.38, 0.0, 1], ["wolf", 10, 0.43, 6.0, 1], ["gargoyle", 9, 0.7, 8.0, 0]],
			[["warchief", 2, 3.0, 0.0, 1], ["orc", 8, 1.3, 2.0, 0], ["shaman", 3, 3.0, 4.0, 1], ["gargoyle", 8, 0.75, 6.0, 0], ["sapper", 4, 0.87, 9.0, 1]],
		],
	},
	{
		"id": "frostwind", "name": "서리바람 고개", "subtitle": "얼어붙은 길",
		"desc": "눈보라 속 늑대 무리와 바위 오우거가 고개를 넘어옵니다.",
		"gold": 500, "lives": 20, "hp_mult": 0.96, "theme": "snow",
		"paths": [[[-38, 10], [-28, 10], [-22, 4], [-22, -6], [-14, -12], [-4, -12], [0, -4], [-4, 6], [2, 12], [12, 12], [16, 4], [12, -6], [18, -13], [26, -11], [28, -2], [37, 0]]],
		"plots_auto": 14, "hero_start": [-2, 0], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["wolf", 11, 0.49, 0.0, 0]],
			[["goblin", 14, 0.51, 0.0, 0], ["wolf", 5, 0.45, 5.0, 0]],
			[["orc", 4, 2.2, 0.0, 0], ["shaman", 2, 3.0, 3.0, 0]],
			[["wolf", 9, 0.64, 0.0, 0], ["gargoyle", 3, 1.8, 4.0, 0]],
			[["ogre", 1, 1.0, 0.0, 0], ["goblin", 3, 0.8, 2.0, 0]],
			[["sapper", 3, 2.4, 0.0, 0], ["orc", 4, 2.0, 3.0, 0], ["wolf", 8, 0.5, 6.0, 0]],
			[["gargoyle", 10, 0.8, 0.0, 0], ["shaman", 3, 2.0, 2.0, 0], ["spear", 6, 1.0, 4.0, 0]],
			[["ogre", 1, 6.0, 0.0, 0], ["wolf", 9, 0.55, 3.0, 0], ["orc", 2, 2.88, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 4, 2.24, 1.0, 0], ["sapper", 3, 2.1, 5.0, 0], ["gargoyle", 4, 1.44, 6.0, 0]],
			[["wolf", 34, 0.28, 0.0, 0], ["goblin", 28, 0.28, 3.0, 0], ["shaman", 7, 0.9, 5.0, 0]],
			[["ogre", 2, 6.0, 0.0, 0], ["orc", 8, 1.3, 2.0, 0], ["gargoyle", 9, 0.79, 6.0, 0]],
			[["warchief", 2, 4.0, 0.0, 0], ["ogre", 2, 6.0, 3.0, 0], ["wolf", 15, 0.37, 5.0, 0], ["sapper", 5, 1.2, 9.0, 0], ["gargoyle", 7, 0.93, 12.0, 0]],
		],
	},
	{
		"id": "moonwood", "name": "달빛 숲", "subtitle": "밤의 습격",
		"desc": "달빛 아래 두 갈래 숲길로 가고일과 폭탄병이 숨어듭니다.",
		"gold": 560, "lives": 20, "hp_mult": 0.85, "theme": "night",
		"paths": [
			[[-38, -15], [-26, -15], [-18, -8], [-10, -8], [-4, -2], [4, -2], [10, 4], [18, 4], [24, -2], [30, -2], [37, -2]],
			[[-16, 28], [-16, 18], [-12, 10], [-8, 4], [-4, -2], [4, -2], [10, 4], [18, 4], [24, -2], [30, -2], [37, -2]],
		],
		"plots_auto": 15, "hero_start": [2, 2], "bounds": [-30, 30, -18, 17],
		"waves": [
			[["goblin", 10, 0.62, 0.0, 0], ["spear", 6, 1.0, 1.0, 1]],
			[["gargoyle", 4, 1.2, 0.0, 0], ["wolf", 6, 0.6, 2.0, 1]],
			[["orc", 3, 3.0, 0.0, 1], ["sapper", 4, 1.07, 2.0, 0], ["shaman", 2, 2.5, 4.0, 1]],
			[["wolf", 10, 0.39, 0.0, 0], ["wolf", 10, 0.39, 0.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["gargoyle", 3, 1.28, 2.0, 1], ["rogue", 3, 1.5, 4.0, 0]],
			[["sapper", 4, 1.6, 0.0, 1], ["orc", 6, 1.6, 2.0, 0], ["shaman", 3, 2.0, 4.0, 0]],
			[["gargoyle", 11, 0.7, 0.0, 0], ["rogue", 8, 0.8, 2.0, 1]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 2, 2.56, 1.0, 0], ["ogre", 1, 1.0, 8.0, 1], ["wolf", 3, 0.72, 10.0, 1]],
			[["sapper", 6, 1.0, 0.0, 0], ["sapper", 8, 0.71, 0.0, 1], ["gargoyle", 12, 0.51, 5.0, 0]],
			[["ogre", 2, 5.0, 0.0, 0], ["ogre", 1, 5.0, 2.0, 1], ["shaman", 3, 2.56, 4.0, 0], ["rogue", 4, 1.71, 6.0, 1]],
			[["warchief", 2, 3.0, 0.0, 1], ["orc", 11, 0.99, 2.0, 0], ["gargoyle", 10, 0.73, 6.0, 1]],
			[["wolf", 17, 0.29, 0.0, 0], ["sapper", 6, 0.88, 3.0, 1], ["ogre", 2, 7.0, 7.0, 0], ["gargoyle", 11, 0.49, 9.0, 1]],
			[["warchief", 2, 4.0, 0.0, 0], ["ogre", 2, 6.0, 3.0, 1], ["orc", 10, 0.8, 4.0, 1], ["shaman", 4, 1.6, 6.0, 0], ["gargoyle", 13, 0.49, 10.0, 0]],
		],
	},
	{
		"id": "trollgorge", "name": "트롤왕의 협곡", "subtitle": "트롤 군주의 진군",
		"desc": "황혼의 협곡. 트롤 군주 그롬이 직접 진군합니다.",
		"gold": 620, "lives": 20, "hp_mult": 1.11, "theme": "autumn",
		"paths": [[[-38, -7], [-28, -7], [-24, -15], [-14, -16], [-10, -7], [-14, 3], [-9, 12], [1, 12], [6, 3], [4, -7], [11, -14], [19, -12], [22, -3], [18, 7], [25, 13], [37, 13]]],
		"plots_auto": 16, "hero_start": [0, 4], "bounds": [-30, 30, -19, 17],
		"waves": [
			[["goblin", 13, 0.52, 0.0, 0], ["wolf", 6, 0.48, 5.0, 0]],
			[["orc", 3, 3.0, 0.0, 0], ["goblin", 11, 0.54, 2.0, 0]],
			[["gargoyle", 5, 1.25, 0.0, 0], ["wolf", 7, 0.58, 4.0, 0], ["sapper", 2, 2.0, 6.0, 0]],
			[["shaman", 3, 2.25, 0.0, 0], ["orc", 3, 2.88, 2.0, 0], ["spear", 4, 1.33, 6.0, 0]],
			[["ogre", 1, 1.0, 0.0, 0], ["gargoyle", 3, 1.28, 2.0, 0], ["wolf", 3, 0.64, 5.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 3, 2.08, 1.0, 0], ["sapper", 4, 1.4, 5.0, 0]],
			[["rogue", 10, 0.67, 0.0, 0], ["gargoyle", 9, 0.79, 4.0, 0]],
			[["ogre", 1, 5.0, 0.0, 0], ["shield", 2, 4.16, 2.0, 0], ["wolf", 8, 0.55, 6.0, 0]],
			[["gargoyle", 13, 0.55, 0.0, 0], ["shaman", 5, 1.5, 2.0, 0], ["sapper", 5, 1.2, 6.0, 0]],
			[["warchief", 2, 3.5, 0.0, 0], ["goblin", 26, 0.31, 1.0, 0], ["wolf", 22, 0.28, 8.0, 0]],
			[["ogre", 3, 4.0, 0.0, 0], ["orc", 5, 1.41, 2.0, 0], ["shield", 2, 3.0, 4.0, 0], ["shaman", 3, 3.19, 6.0, 0]],
			[["gargoyle", 21, 0.38, 0.0, 0], ["sapper", 8, 0.71, 3.0, 0], ["wolf", 21, 0.28, 6.0, 0]],
			[["warchief", 3, 3.0, 0.0, 0], ["ogre", 1, 6.0, 4.0, 0], ["orc", 9, 1.38, 6.0, 0], ["gargoyle", 6, 1.12, 10.0, 0]],
			[["troll", 1, 1.0, 6.0, 0], ["orc", 14, 0.83, 0.0, 0], ["warchief", 2, 4.0, 10.0, 0], ["goblin", 23, 0.35, 14.0, 0], ["gargoyle", 13, 0.6, 18.0, 0], ["ogre", 2, 6.0, 24.0, 0]],
		],
	},
	{
		"id": "citadel", "name": "검은 성채", "subtitle": "점령당한 트롤 요새",
		"desc": "트롤왕이 쓰러지자 망자의 군단이 그의 성채를 차지했습니다. 두 성문에서 해골 무리가 쏟아져 나옵니다.",
		"gold": 700, "lives": 20, "hp_mult": 0.99, "theme": "necro",
		"paths": [
			[[-38, 11], [-29, 11], [-23, 5], [-14, 5], [-9, 12], [-1, 12], [5, 6], [5, -2], [11, -6], [19, -6], [24, 0], [29, 6], [37, 6]],
			[[-38, -14], [-29, -14], [-21, -10], [-13, -12], [-5, -8], [0, -3], [5, -2], [11, -6], [19, -6], [24, 0], [29, 6], [37, 6]],
		],
		"plots_auto": 18, "hero_start": [4, 2], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["skeleton", 10, 0.8, 0.0, 0], ["skeleton", 7, 0.93, 3.0, 1]],
			[["rogue", 5, 1.12, 0.0, 1], ["wolf", 6, 0.6, 3.0, 0]],
			[["skeleton", 11, 0.65, 0.0, 0], ["gargoyle", 5, 1.1, 2.0, 1]],
			[["skeleton_knight", 2, 3.0, 0.0, 0], ["skeleton", 5, 0.8, 2.0, 1]],
			[["orc", 3, 2.7, 0.0, 1], ["shaman", 3, 2.0, 2.0, 1], ["skeleton", 10, 0.65, 0.0, 0]],
			[["skeleton_knight", 3, 3.6, 0.0, 0], ["sapper", 5, 1.05, 3.0, 1]],
			[["gargoyle", 11, 0.72, 0.0, 0], ["wolf", 12, 0.4, 2.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["skeleton_knight", 2, 3.52, 2.0, 1], ["skeleton", 3, 0.64, 5.0, 0]],
			[["warchief", 1, 1.0, 0.0, 1], ["orc", 5, 1.75, 1.0, 1], ["skeleton", 14, 0.46, 0.0, 0]],
			[["skeleton_knight", 5, 2.25, 0.0, 0], ["shaman", 3, 2.7, 3.0, 0], ["gargoyle", 6, 0.98, 5.0, 1]],
			[["sapper", 14, 0.38, 0.0, 0], ["sapper", 15, 0.36, 0.0, 1], ["wolf", 35, 0.28, 6.0, 0]],
			[["ogre", 2, 5.0, 0.0, 0], ["skeleton_knight", 3, 2.88, 2.0, 1], ["skeleton", 18, 0.4, 6.0, 1]],
			[["warchief", 2, 4.0, 0.0, 0], ["orc", 9, 1.2, 2.0, 1], ["gargoyle", 12, 0.53, 6.0, 0]],
			[["skeleton_knight", 8, 1.37, 0.0, 0], ["skeleton_knight", 5, 1.6, 3.0, 1], ["shaman", 5, 1.2, 6.0, 0], ["skeleton", 21, 0.3, 8.0, 1]],
			[["ogre", 2, 5.0, 0.0, 1], ["warchief", 2, 4.0, 4.0, 0], ["skeleton_knight", 7, 1.5, 6.0, 0], ["gargoyle", 10, 0.65, 10.0, 1], ["skeleton", 20, 0.32, 12.0, 0]],
		],
	},
	{
		"id": "falls", "name": "통곡의 폭포", "subtitle": "안개 낀 절벽길",
		"desc": "안개 자욱한 폭포 절벽을 따라 해골 기사단과 주술사가 몰려옵니다.",
		"gold": 780, "lives": 20, "hp_mult": 1.01, "theme": "ruins",
		"paths": [
			[[-38, 1], [-29, 1], [-24, -6], [-16, -7], [-11, 0], [-12, 8], [-4, 12], [4, 9], [7, 1], [14, -4], [22, -3], [26, 5], [31, 9], [37, 9]],
			[[3, -30], [3, -21], [7, -14], [10, -8], [14, -4], [22, -3], [26, 5], [31, 9], [37, 9]],
		],
		"plots_auto": 16, "hero_start": [8, 0], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["skeleton", 10, 0.86, 0.0, 0], ["spear", 7, 1.0, 2.0, 1]],
			[["wolf", 8, 0.55, 0.0, 1], ["shaman", 2, 2.0, 2.0, 0], ["skeleton", 10, 0.6, 4.0, 0]],
			[["skeleton_knight", 2, 2.5, 0.0, 0], ["gargoyle", 4, 1.47, 2.0, 1]],
			[["orc", 3, 2.85, 0.0, 1], ["sapper", 3, 1.5, 3.0, 0], ["skeleton", 9, 0.69, 4.0, 1]],
			[["gargoyle", 8, 0.96, 0.0, 0], ["wolf", 8, 0.57, 3.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["skeleton_knight", 2, 3.2, 2.0, 1], ["shaman", 3, 2.7, 4.0, 0]],
			[["skeleton", 30, 0.28, 0.0, 0], ["skeleton", 29, 0.28, 2.0, 1]],
			[["warchief", 1, 1.0, 0.0, 1], ["shield", 3, 3.6, 1.0, 1], ["sapper", 5, 1.2, 4.0, 0]],
			[["skeleton_knight", 4, 2.56, 0.0, 0], ["gargoyle", 7, 1.05, 3.0, 1], ["shaman", 3, 2.4, 6.0, 0]],
			[["ogre", 2, 5.0, 0.0, 1], ["wolf", 19, 0.28, 2.0, 0], ["skeleton", 17, 0.36, 6.0, 1]],
			[["sapper", 8, 0.71, 0.0, 0], ["skeleton_knight", 6, 1.36, 3.0, 1], ["gargoyle", 14, 0.45, 6.0, 0]],
			[["warchief", 2, 4.0, 0.0, 0], ["orc", 4, 2.08, 2.0, 0], ["shaman", 3, 2.25, 4.0, 1], ["skeleton", 12, 0.52, 6.0, 1]],
			[["ogre", 2, 5.0, 0.0, 0], ["skeleton_knight", 6, 1.8, 3.0, 1], ["gargoyle", 9, 0.82, 8.0, 0]],
			[["skeleton_knight", 8, 1.4, 0.0, 0], ["skeleton_knight", 7, 1.4, 2.0, 1], ["wolf", 15, 0.35, 6.0, 0], ["sapper", 5, 1.1, 9.0, 1]],
			[["warchief", 2, 3.0, 0.0, 1], ["ogre", 2, 5.0, 2.0, 0], ["skeleton_knight", 6, 1.82, 5.0, 0], ["gargoyle", 11, 0.66, 8.0, 1], ["skeleton", 20, 0.39, 10.0, 0]],
		],
	},
	{
		"id": "temple", "name": "망자의 신전", "subtitle": "리치 군주의 왕좌",
		"desc": "해안의 고대 신전에서 모든 망자의 근원, 리치 군주 모르가스가 깨어났습니다. 망자의 군대를 끝내야 합니다!",
		"gold": 880, "lives": 20, "hp_mult": 1.21, "theme": "swamp",
		"paths": [
			[[-38, -12], [-29, -12], [-23, -5], [-24, 5], [-17, 12], [-8, 11], [-4, 3], [-9, -5], [-4, -13], [6, -13], [11, -6], [8, 3], [13, 11], [21, 11], [26, 3], [31, -2], [37, -2]],
			[[-8, 30], [-8, 21], [-9, 16], [-8, 11], [-4, 3], [-9, -5], [-4, -13], [6, -13], [11, -6], [8, 3], [13, 11], [21, 11], [26, 3], [31, -2], [37, -2]],
		],
		"plots_auto": 17, "hero_start": [-2, 0], "bounds": [-30, 30, -19, 17],
		"waves": [
			[["skeleton", 15, 0.56, 0.0, 0], ["skeleton", 10, 0.6, 3.0, 1]],
			[["skeleton_knight", 2, 3.84, 0.0, 0], ["wolf", 9, 0.56, 2.0, 1]],
			[["gargoyle", 5, 1.8, 0.0, 1], ["shaman", 3, 2.7, 2.0, 0], ["rogue", 6, 1.12, 4.0, 0]],
			[["orc", 4, 2.56, 0.0, 0], ["sapper", 3, 1.92, 3.0, 1], ["skeleton", 11, 0.6, 5.0, 1]],
			[["ogre", 1, 1.0, 0.0, 1], ["skeleton_knight", 2, 2.88, 2.0, 0], ["gargoyle", 3, 1.28, 5.0, 0]],
			[["skeleton", 25, 0.29, 0.0, 0], ["wolf", 17, 0.33, 3.0, 1], ["shaman", 5, 1.2, 6.0, 0]],
			[["warchief", 1, 1.0, 0.0, 0], ["shield", 3, 3.3, 1.0, 0], ["skeleton_knight", 3, 2.88, 3.0, 1]],
			[["gargoyle", 12, 0.68, 0.0, 0], ["sapper", 7, 1.05, 3.0, 1], ["skeleton", 15, 0.47, 6.0, 1]],
			[["ogre", 1, 5.0, 0.0, 0], ["skeleton_knight", 6, 2.1, 2.0, 1], ["shaman", 3, 2.4, 5.0, 0]],
			[["warchief", 2, 4.0, 0.0, 1], ["orc", 7, 1.65, 2.0, 1], ["wolf", 14, 0.42, 5.0, 0], ["gargoyle", 7, 0.9, 8.0, 0]],
			[["skeleton_knight", 11, 1.12, 0.0, 0], ["skeleton", 27, 0.29, 2.0, 1], ["sapper", 9, 0.62, 6.0, 0]],
			[["ogre", 3, 4.5, 0.0, 1], ["gargoyle", 16, 0.5, 2.0, 0], ["shaman", 7, 1.17, 5.0, 1]],
			[["warchief", 3, 3.0, 0.0, 0], ["skeleton_knight", 8, 1.67, 2.0, 1], ["orc", 9, 1.38, 6.0, 0]],
			[["ogre", 3, 4.5, 0.0, 0], ["skeleton_knight", 9, 1.3, 2.0, 1], ["gargoyle", 14, 0.55, 6.0, 1], ["skeleton", 26, 0.3, 8.0, 0]],
			[["warchief", 3, 3.0, 0.0, 1], ["ogre", 3, 4.5, 2.0, 0], ["skeleton_knight", 14, 1.02, 4.0, 0], ["sapper", 11, 0.63, 8.0, 1], ["wolf", 23, 0.28, 10.0, 0]],
			[["lich", 1, 1.0, 8.0, 0], ["skeleton_knight", 14, 0.81, 0.0, 0], ["skeleton", 40, 0.28, 0.0, 1], ["warchief", 3, 2.0, 14.0, 1], ["gargoyle", 22, 0.31, 18.0, 0], ["ogre", 3, 3.0, 24.0, 1]],
		],
	},
	{
		"id": "harbor", "name": "폭풍 항구", "subtitle": "바다에서 온 침공",
		"desc": "리치가 쓰러진 틈을 타 오우거 군대가 배를 타고 남쪽 항구로 상륙합니다. 항구의 다리를 지키세요.",
		"gold": 920, "lives": 20, "hp_mult": 1.04, "theme": "river",
		"paths": [
			[[-38, -14], [-28, -14], [-22, -8], [-14, -8], [-8, -12], [0, -12], [6, -6], [4, 2], [10, 7], [18, 7], [24, 2], [30, 2], [37, 2]],
			[[-38, 13], [-29, 13], [-23, 9], [-17, 11], [-10, 7], [-4, 2], [4, 2], [10, 7], [18, 7], [24, 2], [30, 2], [37, 2]],
		],
		"river_x": 14.0, "plots_auto": 16, "hero_start": [2, -3], "bounds": [-30, 30, -18, 16],
		"waves": [
			[["orc", 3, 2.7, 0.0, 0], ["spear", 7, 1.05, 2.0, 1]],
			[["sapper", 6, 0.84, 0.0, 1], ["wolf", 15, 0.33, 2.0, 0]],
			[["gargoyle", 4, 2.02, 0.0, 0], ["shield", 3, 2.8, 3.0, 1]],
			[["ogre", 1, 1.0, 0.0, 0], ["goblin", 6, 0.43, 2.0, 1], ["shaman", 3, 2.0, 4.0, 0]],
			[["warchief", 1, 1.0, 0.0, 1], ["orc", 4, 2.24, 1.0, 1], ["sapper", 3, 1.95, 5.0, 0]],
			[["wolf", 15, 0.37, 0.0, 0], ["gargoyle", 12, 0.57, 3.0, 1]],
			[["ogre", 1, 5.0, 0.0, 1], ["orc", 4, 2.08, 2.0, 0], ["shaman", 3, 2.7, 5.0, 1]],
			[["sapper", 9, 0.78, 0.0, 0], ["rogue", 13, 0.56, 2.0, 1], ["wolf", 12, 0.38, 6.0, 0]],
			[["warchief", 2, 4.0, 0.0, 0], ["ogre", 1, 5.0, 3.0, 1], ["gargoyle", 8, 0.82, 6.0, 0]],
			[["orc", 13, 0.92, 0.0, 0], ["shield", 6, 1.6, 1.0, 1], ["shaman", 4, 2.13, 4.0, 0]],
			[["ogre", 4, 3.0, 0.0, 0], ["sapper", 13, 0.52, 3.0, 1], ["wolf", 22, 0.28, 6.0, 1]],
			[["warchief", 2, 3.5, 0.0, 1], ["ogre", 2, 6.0, 2.0, 0], ["orc", 8, 1.57, 4.0, 1], ["gargoyle", 11, 0.71, 8.0, 0]],
		],
	},
	{
		"id": "capital", "name": "왕도 최후의 방어선", "subtitle": "오우거 왕의 진격",
		"desc": "오우거 왕 고르막이 세 갈래 길로 왕도에 진격합니다. 왕국의 운명을 건 마지막 결전!",
		"gold": 980, "lives": 20, "hp_mult": 1.28, "theme": "autumn",
		"paths": [
			[[-38, -2], [-28, -2], [-22, -9], [-14, -9], [-9, -2], [-2, -2], [3, -8], [10, -8], [14, -1], [20, 4], [27, 4], [31, 0], [37, 0]],
			[[-6, 30], [-6, 21], [-3, 14], [3, 10], [8, 10], [12, 5], [14, -1], [20, 4], [27, 4], [31, 0], [37, 0]],
			[[4, -32], [4, -24], [0, -17], [3, -8], [10, -8], [14, -1], [20, 4], [27, 4], [31, 0], [37, 0]],
		],
		"plots_auto": 18, "hero_start": [11, 0], "bounds": [-30, 30, -19, 17],
		"waves": [
			[["goblin", 13, 0.55, 0.0, 0], ["spear", 7, 0.9, 2.0, 1], ["wolf", 7, 0.5, 4.0, 2]],
			[["orc", 3, 2.72, 0.0, 0], ["sapper", 3, 2.1, 2.0, 2], ["gargoyle", 5, 1.2, 3.0, 1]],
			[["ogre", 1, 1.0, 0.0, 1], ["shaman", 3, 2.7, 2.0, 0], ["rogue", 6, 1.12, 3.0, 2]],
			[["warchief", 1, 1.0, 0.0, 0], ["orc", 3, 2.08, 1.0, 0], ["wolf", 7, 0.53, 4.0, 2]],
			[["gargoyle", 8, 1.1, 0.0, 2], ["sapper", 4, 1.17, 2.0, 1], ["orc", 4, 2.4, 4.0, 0]],
			[["ogre", 1, 5.0, 0.0, 0], ["ogre", 1, 1.0, 3.0, 2], ["shaman", 9, 0.8, 4.0, 1]],
			[["rogue", 12, 0.59, 0.0, 1], ["wolf", 15, 0.36, 2.0, 2], ["orc", 9, 1.05, 5.0, 0]],
			[["warchief", 1, 4.0, 0.0, 2], ["orc", 8, 1.41, 2.0, 1], ["gargoyle", 9, 0.82, 5.0, 0]],
			[["ogre", 3, 4.5, 0.0, 1], ["sapper", 9, 0.79, 3.0, 0], ["shaman", 9, 0.75, 5.0, 2]],
			[["orc", 11, 1.1, 0.0, 0], ["shield", 5, 2.0, 1.0, 2], ["wolf", 16, 0.35, 4.0, 1], ["gargoyle", 11, 0.66, 7.0, 0]],
			[["warchief", 2, 3.5, 0.0, 0], ["ogre", 5, 2.25, 2.0, 2], ["sapper", 11, 0.63, 5.0, 1], ["spear", 16, 0.47, 7.0, 0]],
			[["ogre", 4, 4.0, 0.0, 1], ["shield", 6, 1.8, 2.0, 2], ["gargoyle", 14, 0.55, 6.0, 0]],
			[["ogre_king", 1, 1.0, 6.0, 0], ["orc", 18, 0.72, 0.0, 0], ["warchief", 2, 4.0, 8.0, 1], ["ogre", 2, 6.0, 12.0, 2], ["gargoyle", 15, 0.51, 16.0, 1], ["wolf", 17, 0.33, 20.0, 2]],
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
