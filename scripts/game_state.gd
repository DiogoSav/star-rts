extends Node
## Estado global do jogo. Registrado como autoload com o nome "Game".
## Guarda raças, dados de unidades/prédios, créditos, produção e a lista de entidades.

signal message(text: String)
signal game_ended(player_won: bool)

const TILE := 32
const PLAYER := 0
const ENEMY := 1
const START_CREDITS := 5000.0

## A lógica (posições, alcance, caminhos) continua no plano do chão, em "pixels de chão"
## com TILE = 32. No mundo 3D, 1 célula = 1 unidade: x do chão -> X, y do chão -> Z.
const UNIT := 1.0 / TILE
## Altura de voo das naves (unidades do mundo)
const AIR_HEIGHT := 1.35

## Multiplicador de dano: tipo de arma -> tipo de blindagem.
const ARMOR_MULT := {
	"rifle": {"light": 1.0, "medium": 0.4, "heavy": 0.1, "building": 0.25},
	"smg": {"light": 1.2, "medium": 0.3, "heavy": 0.05, "building": 0.2},
	"mg": {"light": 1.1, "medium": 0.45, "heavy": 0.1, "building": 0.25},
	"sniper": {"light": 2.0, "medium": 0.2, "heavy": 0.05, "building": 0.1},
	"at": {"light": 0.3, "medium": 1.1, "heavy": 1.0, "building": 0.7},
	"cannon": {"light": 0.6, "medium": 1.0, "heavy": 1.0, "building": 0.9},
	"missile": {"light": 1.0, "medium": 1.1, "heavy": 0.6, "building": 0.4},
}
## Armas que disparam projéteis visíveis (o dano chega quando o projétil acerta)
const PROJECTILE_WEAPONS := ["at", "cannon", "missile"]

const FACTIONS := {
	"hum": {
		"name": "Humanos", "army": "Legião Solar", "color": Color(0.3, 0.6, 1.0),
		"shot": Color(0.45, 0.8, 1.0),
		"desc": "Equilibrados e versáteis.\nTanques hover Gládio e caças Falcão.",
		"infantry": ["hum_rifle", "hum_smg", "hum_mg", "hum_at", "hum_sniper"],
		"vehicles": ["hum_harvester", "hum_scout", "hum_tank", "hum_heavy"],
		"air": ["hum_fighter", "hum_gunship"],
		"harvester": "hum_harvester", "starter_tank": "hum_tank",
		"buildings": {
			"cy": "Centro de Comando", "power": "Reator de Fusão", "refinery": "Refinaria de Cristal",
			"barracks": "Quartel", "factory": "Fábrica de Blindados", "starport": "Hangar Orbital",
			"turret": "Torre de Defesa", "medic": "Estação Médica",
		},
	},
	"rob": {
		"name": "Robôs", "army": "Núcleo Sintético", "color": Color(1.0, 0.68, 0.2),
		"shot": Color(0.35, 1.0, 0.9),
		"desc": "Caros, lentos de produzir e muito resistentes.\nAndadores Colosso e a Arca Prisma.",
		"infantry": ["rob_rifle", "rob_smg", "rob_mg", "rob_at", "rob_sniper"],
		"vehicles": ["rob_harvester", "rob_scout", "rob_tank", "rob_heavy"],
		"air": ["rob_fighter", "rob_gunship"],
		"harvester": "rob_harvester", "starter_tank": "rob_tank",
		"buildings": {
			"cy": "Núcleo Central", "power": "Matriz de Energia", "refinery": "Processador de Cristal",
			"barracks": "Montadora de Droides", "factory": "Forja Mecânica",
			"starport": "Plataforma Gravitacional", "turret": "Torre de Raios",
			"medic": "Doca de Reparo",
		},
	},
	"ins": {
		"name": "Insetos", "army": "Enxame Kheth", "color": Color(0.55, 0.95, 0.25),
		"shot": Color(0.6, 1.0, 0.25),
		"desc": "Baratos, rápidos e numerosos.\nBesouros blindados e vespas aladas.",
		"infantry": ["ins_rifle", "ins_smg", "ins_mg", "ins_at", "ins_sniper"],
		"vehicles": ["ins_harvester", "ins_scout", "ins_tank", "ins_heavy"],
		"air": ["ins_fighter", "ins_gunship"],
		"harvester": "ins_harvester", "starter_tank": "ins_tank",
		"buildings": {
			"cy": "Colmeia-Mãe", "power": "Nódulo Vital", "refinery": "Digestor de Cristal",
			"barracks": "Incubadora", "factory": "Casulo Profundo", "starport": "Ninho Aéreo",
			"turret": "Espinho Ácido", "medic": "Poço de Regeneração",
		},
	},
}

## Arma: "air" = pode atirar em naves; "ground" = false para naves que só atacam outras naves.
const UNITS := {
	# ---- Legião Solar: equilibrada
	"hum_rifle": {
		"name": "Fuzileiro Orbital", "short": "Fuzileiro", "kind": "inf", "category": "infantry",
		"cost": 100, "time": 3.0, "requires": [], "hp": 55, "speed": 40.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Infantaria básica com fuzil gauss.",
		"weapon": {"damage": 11, "range": 120.0, "cooldown": 1.1, "type": "rifle"},
	},
	"hum_smg": {
		"name": "Tropa de Choque", "short": "Choque", "kind": "inf", "category": "infantry",
		"cost": 140, "time": 3.5, "requires": [], "hp": 60, "speed": 44.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Blaster duplo: devastador de perto contra infantaria.",
		"weapon": {"damage": 6, "range": 80.0, "cooldown": 0.3, "type": "smg"},
	},
	"hum_mg": {
		"name": "Artilheiro de Pulso", "short": "Artilheiro", "kind": "inf", "category": "infantry",
		"cost": 220, "time": 4.5, "requires": [], "hp": 60, "speed": 34.0, "radius": 6.0, "sight": 6,
		"armor": "light", "desc": "Metralhadora rotativa: contra infantaria e NAVES.",
		"weapon": {"damage": 5, "range": 145.0, "cooldown": 0.2, "type": "mg", "air": true},
	},
	"hum_at": {
		"name": "Lança-Mísseis", "short": "Lança-míssil", "kind": "inf", "category": "infantry",
		"cost": 260, "time": 4.5, "requires": [], "hp": 55, "speed": 36.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Mísseis guiados: destrói blindados.",
		"weapon": {"damage": 40, "range": 140.0, "cooldown": 2.3, "type": "at"},
	},
	"hum_sniper": {
		"name": "Atirador de Elite", "short": "Atirador", "kind": "inf", "category": "infantry",
		"cost": 380, "time": 6.0, "requires": ["refinery"], "hp": 40, "speed": 38.0, "radius": 6.0,
		"sight": 8, "armor": "light", "desc": "Rifle de trilho: elimina soldados de muito longe.",
		"weapon": {"damage": 50, "range": 220.0, "cooldown": 3.0, "type": "sniper"},
	},
	"hum_harvester": {
		"name": "Cargueiro Minerador", "short": "Minerador", "kind": "veh", "category": "vehicle",
		"cost": 900, "time": 9.0, "requires": ["refinery"], "hp": 450, "speed": 45.0, "radius": 12.0,
		"sight": 3, "armor": "medium", "harvester": true,
		"desc": "Extrai cristais e leva para a Refinaria.", "weapon": {},
	},
	"hum_scout": {
		"name": "Batedor Lince", "short": "Batedor", "kind": "veh", "category": "vehicle",
		"cost": 450, "time": 6.5, "requires": [], "hp": 200, "speed": 75.0, "radius": 10.0, "sight": 7,
		"armor": "medium", "desc": "Rápido, com canhão de pulso que atinge naves.",
		"weapon": {"damage": 6, "range": 130.0, "cooldown": 0.25, "type": "mg", "air": true},
	},
	"hum_tank": {
		"name": "Tanque Gládio", "short": "Gládio", "kind": "veh", "category": "vehicle",
		"cost": 850, "time": 9.5, "requires": [], "hp": 380, "speed": 58.0, "radius": 12.0, "sight": 6,
		"armor": "heavy", "hover": true, "desc": "Tanque hover com canhão de plasma.",
		"weapon": {"damage": 34, "range": 150.0, "cooldown": 1.6, "type": "cannon"},
	},
	"hum_heavy": {
		"name": "Titã de Cerco", "short": "Titã", "kind": "veh", "category": "vehicle",
		"cost": 1500, "time": 15.0, "requires": ["refinery"], "hp": 750, "speed": 36.0, "radius": 14.0,
		"sight": 7, "armor": "heavy", "desc": "Tanque pesado de canhão duplo: lento e letal.",
		"weapon": {"damage": 65, "range": 175.0, "cooldown": 2.6, "type": "cannon"},
	},
	"hum_fighter": {
		"name": "Caça Falcão", "short": "Falcão", "kind": "air", "category": "air",
		"cost": 700, "time": 8.0, "requires": [], "hp": 160, "speed": 110.0, "radius": 11.0, "sight": 7,
		"armor": "light", "desc": "Caça veloz: mísseis contra naves e alvos no solo.",
		"weapon": {"damage": 18, "range": 140.0, "cooldown": 1.0, "type": "missile", "air": true},
	},
	"hum_gunship": {
		"name": "Fragata Ônix", "short": "Ônix", "kind": "air", "category": "air",
		"cost": 1600, "time": 16.0, "requires": ["refinery"], "hp": 600, "speed": 50.0, "radius": 17.0,
		"sight": 7, "armor": "medium", "desc": "Nave de ataque pesada: torre de plasma (só alvos no solo).",
		"weapon": {"damage": 45, "range": 160.0, "cooldown": 2.0, "type": "cannon"},
	},
	# ---- Núcleo Sintético: caro, lento de produzir, resistente
	"rob_rifle": {
		"name": "Sentinela", "short": "Sentinela", "kind": "inf", "category": "infantry",
		"cost": 130, "time": 4.0, "requires": [], "hp": 70, "speed": 36.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Droide de combate com fuzil de raios.",
		"weapon": {"damage": 13, "range": 125.0, "cooldown": 1.2, "type": "rifle"},
	},
	"rob_smg": {
		"name": "Ceifador", "short": "Ceifador", "kind": "inf", "category": "infantry",
		"cost": 170, "time": 4.5, "requires": [], "hp": 75, "speed": 42.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Emissores gêmeos de curto alcance contra infantaria.",
		"weapon": {"damage": 7, "range": 75.0, "cooldown": 0.3, "type": "smg"},
	},
	"rob_mg": {
		"name": "Supressor", "short": "Supressor", "kind": "inf", "category": "infantry",
		"cost": 260, "time": 5.5, "requires": [], "hp": 75, "speed": 32.0, "radius": 6.0, "sight": 6,
		"armor": "light", "desc": "Canhão de íons rápido: contra infantaria e NAVES.",
		"weapon": {"damage": 6, "range": 145.0, "cooldown": 0.22, "type": "mg", "air": true},
	},
	"rob_at": {
		"name": "Desintegrador", "short": "Desintegr.", "kind": "inf", "category": "infantry",
		"cost": 320, "time": 5.5, "requires": [], "hp": 65, "speed": 34.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Orbe de fusão: derrete blindagem.",
		"weapon": {"damage": 50, "range": 140.0, "cooldown": 2.6, "type": "at"},
	},
	"rob_sniper": {
		"name": "Observador", "short": "Observador", "kind": "inf", "category": "infantry",
		"cost": 420, "time": 6.5, "requires": ["refinery"], "hp": 50, "speed": 38.0, "radius": 6.0,
		"sight": 9, "armor": "light", "desc": "Lança de partículas de longuíssimo alcance.",
		"weapon": {"damage": 55, "range": 230.0, "cooldown": 3.2, "type": "sniper"},
	},
	"rob_harvester": {
		"name": "Extrator", "short": "Extrator", "kind": "veh", "category": "vehicle",
		"cost": 1000, "time": 10.0, "requires": ["refinery"], "hp": 520, "speed": 44.0, "radius": 12.0,
		"sight": 3, "armor": "medium", "harvester": true, "hover": true,
		"desc": "Plataforma flutuante que extrai cristais.", "weapon": {},
	},
	"rob_scout": {
		"name": "Aranha", "short": "Aranha", "kind": "veh", "category": "vehicle",
		"cost": 520, "time": 7.0, "requires": [], "hp": 260, "speed": 66.0, "radius": 11.0, "sight": 7,
		"armor": "medium", "desc": "Andador de quatro patas com torre antiaérea.",
		"weapon": {"damage": 7, "range": 135.0, "cooldown": 0.25, "type": "mg", "air": true},
	},
	"rob_tank": {
		"name": "Bastião", "short": "Bastião", "kind": "veh", "category": "vehicle",
		"cost": 950, "time": 10.5, "requires": [], "hp": 450, "speed": 52.0, "radius": 13.0, "sight": 6,
		"armor": "heavy", "hover": true, "desc": "Disco blindado flutuante com canhão de raios.",
		"weapon": {"damage": 38, "range": 155.0, "cooldown": 1.7, "type": "cannon"},
	},
	"rob_heavy": {
		"name": "Colosso", "short": "Colosso", "kind": "veh", "category": "vehicle",
		"cost": 1700, "time": 16.0, "requires": ["refinery"], "hp": 900, "speed": 32.0, "radius": 15.0,
		"sight": 7, "armor": "heavy", "desc": "Mecha bípede com canhões de fusão gêmeos.",
		"weapon": {"damage": 70, "range": 180.0, "cooldown": 2.6, "type": "cannon"},
	},
	"rob_fighter": {
		"name": "Interceptor Delta", "short": "Delta", "kind": "air", "category": "air",
		"cost": 800, "time": 9.0, "requires": [], "hp": 200, "speed": 105.0, "radius": 11.0, "sight": 7,
		"armor": "light", "desc": "Interceptor: mísseis contra naves e alvos no solo.",
		"weapon": {"damage": 20, "range": 145.0, "cooldown": 1.1, "type": "missile", "air": true},
	},
	"rob_gunship": {
		"name": "Arca Prisma", "short": "Prisma", "kind": "air", "category": "air",
		"cost": 1800, "time": 17.0, "requires": ["refinery"], "hp": 720, "speed": 45.0, "radius": 18.0,
		"sight": 8, "armor": "medium", "desc": "Fortaleza voadora com lança de energia (só solo).",
		"weapon": {"damage": 55, "range": 165.0, "cooldown": 2.2, "type": "cannon"},
	},
	# ---- Enxame Kheth: barato, rápido e frágil
	"ins_rifle": {
		"name": "Zangão", "short": "Zangão", "kind": "inf", "category": "infantry",
		"cost": 80, "time": 2.4, "requires": [], "hp": 45, "speed": 46.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Guerreiro que dispara espinhos. Barato e numeroso.",
		"weapon": {"damage": 10, "range": 115.0, "cooldown": 1.0, "type": "rifle"},
	},
	"ins_smg": {
		"name": "Rasgador", "short": "Rasgador", "kind": "inf", "category": "infantry",
		"cost": 110, "time": 2.8, "requires": [], "hp": 58, "speed": 54.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Foices afiadas: corpo a corpo veloz contra infantaria.",
		"weapon": {"damage": 8, "range": 45.0, "cooldown": 0.35, "type": "smg"},
	},
	"ins_mg": {
		"name": "Cuspidor", "short": "Cuspidor", "kind": "inf", "category": "infantry",
		"cost": 180, "time": 3.6, "requires": [], "hp": 50, "speed": 38.0, "radius": 6.0, "sight": 6,
		"armor": "light", "desc": "Jatos de ácido: contra infantaria e NAVES.",
		"weapon": {"damage": 5, "range": 135.0, "cooldown": 0.22, "type": "mg", "air": true},
	},
	"ins_at": {
		"name": "Perfurador", "short": "Perfurador", "kind": "inf", "category": "infantry",
		"cost": 220, "time": 3.8, "requires": [], "hp": 55, "speed": 40.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Lança espinhos explosivos que furam blindagem.",
		"weapon": {"damage": 38, "range": 120.0, "cooldown": 2.2, "type": "at"},
	},
	"ins_sniper": {
		"name": "Espreitador", "short": "Espreitador", "kind": "inf", "category": "infantry",
		"cost": 320, "time": 5.0, "requires": ["refinery"], "hp": 35, "speed": 44.0, "radius": 6.0,
		"sight": 8, "armor": "light", "desc": "Ferrão-agulha venenoso de longo alcance.",
		"weapon": {"damage": 45, "range": 215.0, "cooldown": 2.8, "type": "sniper"},
	},
	"ins_harvester": {
		"name": "Larva Coletora", "short": "Larva", "kind": "veh", "category": "vehicle",
		"cost": 800, "time": 8.0, "requires": ["refinery"], "hp": 380, "speed": 48.0, "radius": 12.0,
		"sight": 3, "armor": "medium", "harvester": true,
		"desc": "Devora cristais e os leva ao Digestor.", "weapon": {},
	},
	"ins_scout": {
		"name": "Corredor", "short": "Corredor", "kind": "veh", "category": "vehicle",
		"cost": 380, "time": 5.5, "requires": [], "hp": 170, "speed": 85.0, "radius": 11.0, "sight": 7,
		"armor": "medium", "desc": "Besouro veloz que cospe ácido em naves e soldados.",
		"weapon": {"damage": 6, "range": 120.0, "cooldown": 0.25, "type": "mg", "air": true},
	},
	"ins_tank": {
		"name": "Escaravelho", "short": "Escaravelho", "kind": "veh", "category": "vehicle",
		"cost": 720, "time": 8.0, "requires": [], "hp": 340, "speed": 62.0, "radius": 13.0, "sight": 6,
		"armor": "heavy", "desc": "Carapaça grossa e chifre que dispara plasma biológico.",
		"weapon": {"damage": 30, "range": 140.0, "cooldown": 1.4, "type": "cannon"},
	},
	"ins_heavy": {
		"name": "Behemoth", "short": "Behemoth", "kind": "veh", "category": "vehicle",
		"cost": 1350, "time": 13.0, "requires": ["refinery"], "hp": 680, "speed": 40.0, "radius": 16.0,
		"sight": 7, "armor": "heavy", "desc": "Colosso vivo coberto de espinhos de cristal.",
		"weapon": {"damage": 62, "range": 165.0, "cooldown": 2.4, "type": "cannon"},
	},
	"ins_fighter": {
		"name": "Vespa", "short": "Vespa", "kind": "air", "category": "air",
		"cost": 600, "time": 7.0, "requires": [], "hp": 130, "speed": 120.0, "radius": 11.0, "sight": 7,
		"armor": "light", "desc": "Ferrões teleguiados contra naves e alvos no solo.",
		"weapon": {"damage": 16, "range": 130.0, "cooldown": 0.9, "type": "missile", "air": true},
	},
	"ins_gunship": {
		"name": "Leviatã", "short": "Leviatã", "kind": "air", "category": "air",
		"cost": 1450, "time": 14.0, "requires": ["refinery"], "hp": 560, "speed": 52.0, "radius": 18.0,
		"sight": 7, "armor": "medium", "desc": "Arraia gigante que despeja ácido (só solo).",
		"weapon": {"damage": 50, "range": 150.0, "cooldown": 2.0, "type": "cannon"},
	},
}

## Os nomes dos prédios mudam por raça (FACTIONS[...]["buildings"]); estes são os genéricos.
const BUILDINGS := {
	# "cost" do centro de comando só entra no cálculo do conserto (ele não é construível)
	"cy": {
		"name": "Centro de Comando", "category": "", "cost": 3000, "time": 0.0, "requires": [],
		"hp": 1500, "size": Vector2i(3, 3), "power": 10, "sight": 6, "produces": "building",
		"desc": "Centro de comando: constrói os outros prédios.",
	},
	"power": {
		"name": "Gerador", "category": "building", "cost": 300, "time": 6.0, "requires": [],
		"hp": 400, "size": Vector2i(2, 2), "power": 100, "sight": 4, "produces": "",
		"desc": "Gera energia para a base.",
	},
	"refinery": {
		"name": "Refinaria", "category": "building", "cost": 1000, "time": 10.0, "requires": ["power"],
		"hp": 900, "size": Vector2i(3, 2), "power": -40, "sight": 4, "produces": "",
		"desc": "Transforma cristais em créditos. Vem com um coletor.",
	},
	"barracks": {
		"name": "Quartel", "category": "building", "cost": 300, "time": 6.0, "requires": ["power"],
		"hp": 600, "size": Vector2i(2, 2), "power": -20, "sight": 4, "produces": "infantry",
		"desc": "Treina infantaria.",
	},
	"factory": {
		"name": "Fábrica", "category": "building", "cost": 1200, "time": 12.0,
		"requires": ["refinery"], "hp": 1000, "size": Vector2i(3, 3), "power": -30, "sight": 4,
		"produces": "vehicle", "desc": "Monta coletores, batedores e tanques.",
	},
	"starport": {
		"name": "Hangar", "category": "building", "cost": 1500, "time": 13.0,
		"requires": ["factory"], "hp": 1000, "size": Vector2i(3, 3), "power": -40, "sight": 5,
		"produces": "air", "desc": "Constrói caças e naves de ataque.",
	},
	"turret": {
		"name": "Torre", "category": "building", "cost": 600, "time": 8.0, "requires": ["barracks"],
		"hp": 500, "size": Vector2i(1, 1), "power": -20, "sight": 6, "produces": "",
		"desc": "Defesa contra solo e naves. Precisa de energia.",
		"weapon": {"damage": 28, "range": 175.0, "cooldown": 1.3, "type": "cannon", "air": true},
	},
	## Cura: "range" em pixels de chão, "rate" = fração da vida máxima recuperada por segundo
	"medic": {
		"name": "Estação de Cura", "category": "building", "cost": 700, "time": 9.0,
		"requires": ["barracks"], "hp": 500, "size": Vector2i(2, 2), "power": -25, "sight": 5,
		"produces": "", "heal": {"range": 160.0, "rate": 0.03},
		"desc": "Recupera a vida das suas unidades em volta (soldados, veículos e naves). Precisa de energia.",
	},
}

## Itens por categoria de unidade na produção (o ativo + a fila de espera)
const MAX_QUEUE := 5
## População: quanto cada unidade ocupa, pela função (o sufixo do id: hum_tank -> "tank").
const POP_COST := {"rifle": 1, "smg": 1, "mg": 1, "at": 1, "sniper": 1,
		"harvester": 2, "scout": 2, "fighter": 2, "tank": 3, "heavy": 4, "gunship": 4}
## Limite inicial, quanto cada gerador de energia pronto acrescenta, e o máximo absoluto
const POP_BASE := 30
const POP_PER_POWER := 20
const POP_MAX := 100
const BUILD_ORDER := ["power", "refinery", "barracks", "factory", "starport", "turret", "medic"]
const CATEGORY_NAMES := {"building": "construções", "infantry": "infantaria",
		"vehicle": "veículos", "air": "naves"}
## Tamanhos de mapa: escala sobre o mapa pequeno (64×48 células)
const MAP_SIZES := {
	"small": {"name": "Pequeno", "scale": 1.0},
	"medium": {"name": "Médio", "scale": 1.35},
	"large": {"name": "Grande", "scale": 1.6},
}

## Raça escolhida no menu (persiste entre partidas). enemy_choice "" = aleatória.
var player_faction := "hum"
## Nome do jogador no multiplayer (persiste entre partidas)
var player_name := ""
## Tamanho do mapa escolhido (MAP_SIZES); no multiplayer quem escolhe é o anfitrião
var map_size := "small"
## Time controlado por este computador (no multiplayer o convidado é o time 1)
var local_team := PLAYER
## Raças da partida multiplayer: [anfitrião, convidado]
var net_factions: Array = []
## IDs de rede de todas as entidades (iguais no anfitrião e no convidado)
var _ids := {}
var _next_id := 1
var _types: Array = []
var enemy_choice := ""
## Raça de cada time: [jogador, inimigo]
var factions: Array = ["hum", "ins"]
var credits: Array = [START_CREDITS, START_CREDITS]
var map: Map = null
var world: Node3D = null
var fog: Fog = null
var entities: Array = []
## Uma fila por time: categoria -> {"type", "progress", "done"}
var production: Array = [{}, {}]
## Fila de espera (já paga) depois do trabalho ativo: categoria -> [tipos]. Prédios não têm fila.
var queues: Array = [{}, {}]
var game_over := false
## Ícones dos modelos 3D, renderizados uma vez em SubViewports: nome do modelo -> textura
var _icons := {}


func _ready() -> void:
	# Renderiza todos os ícones logo no início, antes de a névoa de guerra existir
	for f in FACTIONS:
		for id in FACTIONS[f]["infantry"] + FACTIONS[f]["vehicles"] + FACTIONS[f]["air"]:
			icon(id)
		for b in BUILDINGS:
			icon(b + "_" + f)


func _exit_tree() -> void:
	Models.clear_cache()


## Ponto do chão (pixels de chão) no mundo 3D, a `h` unidades de altura.
static func to3d(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x * UNIT, h, p.y * UNIT)


static func to_ground(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z) / UNIT


## Ícone de um modelo 3D (vista 3/4) para botões e menus.
func icon(model_name: String) -> Texture2D:
	if _icons.has(model_name):
		return _icons[model_name]
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 120)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Renderiza alguns quadros (texturas e shaders prontos) e depois congela a imagem
	get_tree().create_timer(0.6).timeout.connect(
			func(): vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	add_child(vp)

	var model := Models.instantiate(model_name)
	vp.add_child(model)
	Models.set_tint(model, Color.WHITE, true)   # ícones ignoram a névoa de guerra
	var fkey := model_name.get_slice("_", 0) if UNITS.has(model_name) else model_name.get_slice("_", 1)
	if FACTIONS.has(fkey):
		Models.set_team(model, FACTIONS[fkey]["color"])
	var box := Models.aabb(model_name)
	var center := box.get_center()
	var building := not UNITS.has(model_name)
	var infantry: bool = UNITS.has(model_name) and UNITS[model_name]["kind"] == "inf"
	var dir := Vector3(0.75, 0.75, 1.0)    # veículos e naves: de lado, um pouco de frente
	if building:
		dir = Vector3(0.45, 0.9, 1.0)      # prédios: como na partida, de frente e de cima
	elif infantry:
		dir = Vector3(1.0, 0.45, 0.8)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = box.size.length() * (0.62 if infantry else 0.55)
	vp.add_child(cam)
	cam.look_at_from_position(center + dir.normalized() * 8.0, center)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.light_energy = 1.3
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.3, -1.0, -0.7))
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.7, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	rim.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.3, 0.8))
	var tex := vp.get_texture()
	_icons[model_name] = tex
	return tex


func reset() -> void:
	var enemy := enemy_choice
	if enemy == "" or enemy == player_faction:
		var others: Array = FACTIONS.keys().filter(func(k): return k != player_faction)
		enemy = others.pick_random()
	factions = [player_faction, enemy]
	if Net.active:
		factions = net_factions.duplicate()
	_ids = {}
	_next_id = 1
	credits = [START_CREDITS, START_CREDITS]
	entities = []
	production = [{}, {}]
	queues = [{}, {}]
	game_over = false
	map = null
	world = null
	fog = null


func faction(team: int) -> Dictionary:
	return FACTIONS[factions[team]]


func team_color(team: int) -> Color:
	return faction(team)["color"]


func item_data(type: String) -> Dictionary:
	if UNITS.has(type):
		return UNITS[type]
	return BUILDINGS[type]


## Nome de uma unidade ou prédio (prédios têm nome próprio em cada raça).
func item_name(type: String, team := -1) -> String:
	if BUILDINGS.has(type):
		return faction(local_team if team < 0 else team)["buildings"].get(type, BUILDINGS[type]["name"])
	return UNITS[type]["name"]


# ---------------------------------------------------------------- consultas

func has_building(team: int, type: String) -> bool:
	for e in entities:
		if e is Building and e.team == team and e.type == type and e.built:
			return true
	return false


func building_count(team: int) -> int:
	var n := 0
	for e in entities:
		if e is Building and e.team == team:
			n += 1
	return n


func producer_for(team: int, category: String) -> Building:
	for e in entities:
		if e is Building and e.team == team and e.data["produces"] == category and e.built:
			return e
	return null


func nearest_building(team: int, type: String, pos: Vector2) -> Building:
	var best: Building = null
	var best_d := INF
	for e in entities:
		if e is Building and e.team == team and e.type == type and e.built:
			var d: float = pos.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	return best


## Inimigo mais próximo que `attacker` consegue atingir (naves só com armas antiaéreas).
func nearest_enemy(pos: Vector2, team: int, max_dist: float, attacker: Entity = null) -> Entity:
	var best: Entity = null
	var best_d := max_dist
	for e in entities:
		if e.team == team or e.dead:
			continue
		if attacker != null and not attacker.can_hit(e):
			continue
		var d: float = pos.distance_to(e.position) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best


## x = energia gerada, y = energia consumida
func get_power(team: int) -> Vector2i:
	var made := 0
	var used := 0
	for e in entities:
		if e is Building and e.team == team and e.built:
			var p: int = e.data["power"]
			if p > 0:
				made += p
			else:
				used -= p
	return Vector2i(made, used)


func low_power(team: int) -> bool:
	var p := get_power(team)
	return p.y > p.x


func requirements_met(team: int, type: String) -> bool:
	for r in item_data(type)["requires"]:
		if not has_building(team, r):
			return false
	return true


func can_produce(team: int, type: String) -> bool:
	var cat: String = item_data(type)["category"]
	return producer_for(team, cat) != null and requirements_met(team, type)


# ---------------------------------------------------------------- população

func pop_cost(type: String) -> int:
	return POP_COST.get(type.get_slice("_", 1), 1) if UNITS.has(type) else 0


## População em uso: unidades vivas mais as que estão sendo produzidas ou na fila
## (a fila já reserva o espaço).
func pop_used(team: int) -> int:
	var n := 0
	for e in entities:
		if e is Unit and e.team == team and not e.dead:
			n += pop_cost(e.type)
	return n + pop_reserved(team)


func pop_reserved(team: int) -> int:
	var n := 0
	for cat in ["infantry", "vehicle", "air"]:
		if production[team].has(cat):
			n += pop_cost(production[team][cat]["type"])
		for t in queued(team, cat):
			n += pop_cost(t)
	return n


func pop_cap(team: int) -> int:
	var powers := 0
	for e in entities:
		if e is Building and e.team == team and e.type == "power" and e.built:
			powers += 1
	return mini(POP_MAX, POP_BASE + powers * POP_PER_POWER)


## Cabe mais um `type` na população?
func pop_room(team: int, type: String) -> bool:
	return pop_used(team) + pop_cost(type) <= pop_cap(team)


# ---------------------------------------------------------------- produção

## Começa a produzir `type` ou, se a categoria já está ocupada, põe na fila (paga na hora).
func start_production(team: int, type: String) -> bool:
	if UNITS.has(type) and not pop_room(team, type):
		var msg := "Limite de população: %d / %d" % [pop_used(team), pop_cap(team)]
		if pop_cap(team) < POP_MAX:
			msg += " — construa mais %s (+%d cada)" % [item_name("power", team), POP_PER_POWER]
		notify(team, msg)
		return false
	if Net.is_client():
		Net.order("produce", [type])
		return true
	var data := item_data(type)
	var cat: String = data["category"]
	if not can_produce(team, type):
		return false
	var busy: bool = production[team].has(cat)
	if busy and (cat == "building" or queued(team, cat).size() + 1 >= MAX_QUEUE):
		if cat != "building":
			notify(team, "Fila de produção cheia (máximo %d)" % MAX_QUEUE)
		return false
	if credits[team] < data["cost"]:
		notify(team, "Créditos insuficientes")
		return false
	credits[team] -= data["cost"]
	if busy:
		queued(team, cat).append(type)
	else:
		production[team][cat] = {"type": type, "progress": 0.0, "done": false}
	return true


func queued(team: int, cat: String) -> Array:
	if not queues[team].has(cat):
		queues[team][cat] = []
	return queues[team][cat]


## Quantos itens de `type` estão na produção (o ativo mais os da fila).
func count_in_production(team: int, type: String) -> int:
	var cat: String = item_data(type)["category"]
	var n := queued(team, cat).count(type)
	if production[team].has(cat) and production[team][cat]["type"] == type:
		n += 1
	return n


## Cancela um `type` (o último da fila; se não houver na fila, o que está sendo produzido)
## e devolve os créditos.
func cancel_production(team: int, cat: String, type := "") -> void:
	if Net.is_client():
		Net.order("cancel", [cat, type])
		return
	var q := queued(team, cat)
	var i := q.rfind(type) if type != "" else -1
	if i >= 0:
		q.remove_at(i)
		credits[team] += item_data(type)["cost"]
	elif production[team].has(cat) and (type == "" or production[team][cat]["type"] == type):
		credits[team] += item_data(production[team][cat]["type"])["cost"]
		production[team].erase(cat)
		_next_job(team, cat)
	else:
		return
	notify(team, "Produção cancelada")


## Passa o próximo da fila para a produção.
func _next_job(team: int, cat: String) -> void:
	var q := queued(team, cat)
	if not q.is_empty() and not production[team].has(cat):
		production[team][cat] = {"type": q.pop_front(), "progress": 0.0, "done": false}


func _process(delta: float) -> void:
	if game_over or map == null or Net.is_client():
		return
	for team in 2:
		var mult := 0.5 if low_power(team) else 1.0
		for cat in production[team].keys():
			var job: Dictionary = production[team][cat]
			if job["done"]:
				continue
			var producer := producer_for(team, cat)
			if producer == null:
				continue # produção pausada sem o prédio produtor
			job["progress"] += delta / float(item_data(job["type"])["time"]) * mult
			if job["progress"] >= 1.0:
				job["progress"] = 1.0
				if cat == "building":
					job["done"] = true
					notify(team, "Construção pronta: clique no botão e posicione no mapa")
					if team == local_team:
						Sfx.ui("ready")
				else:
					var pos := producer.position if cat == "air" else producer.exit_position()
					var u := spawn_unit(job["type"], team, pos)
					if producer.has_rally:
						u.command_move(producer.rally)   # coletor: o ponto vira o campo de trabalho
					if team == local_team:
						Sfx.ui("ready")
					production[team].erase(cat)
					_next_job(team, cat)


# ---------------------------------------------------------------- criação

func spawn_unit(type: String, team: int, pos: Vector2) -> Unit:
	var u: Unit
	if UNITS[type].get("harvester", false):
		u = Harvester.new()
	else:
		u = Unit.new()
	u.setup(type, team)
	u.position = pos
	world.add_child(u)
	entities.append(u)
	set_net_id(u, _next_id)
	return u


## Com `animate`, o prédio sobe do chão e só funciona quando termina (ver Building).
func spawn_building(type: String, team: int, cell: Vector2i, animate := false) -> Building:
	var b := Building.new()
	b.setup(type, team, cell)
	world.add_child(b)
	entities.append(b)
	set_net_id(b, _next_id)
	map.set_cells_blocked(b.cell, b.size, true)
	for e in entities:
		if e is Unit:
			e.repath()
	if animate:
		b.start_construction()
	else:
		b.finish_construction()
	return b


func can_place(type: String, team: int, cell: Vector2i) -> bool:
	var size: Vector2i = BUILDINGS[type]["size"]
	for x in size.x:
		for y in size.y:
			if not map.is_buildable(cell + Vector2i(x, y)):
				return false
	var rect := Rect2(Vector2(cell) * TILE, Vector2(size) * TILE).grow(4.0)
	var area := Rect2i(cell, size)
	var near_base := false
	for e in entities:
		if e is Unit and not e.flying and rect.has_point(e.position):
			return false
		if e is Building and e.team == team and Rect2i(e.cell, e.size).grow(4).intersects(area):
			near_base = true
	return near_base


func place_building(type: String, team: int, cell: Vector2i) -> bool:
	if Net.is_client():
		if not can_place(type, team, cell):
			return false
		Net.order("place", [type, cell])
		return true
	var job: Dictionary = production[team].get("building", {})
	if job.is_empty() or not job["done"] or job["type"] != type:
		return false
	if not can_place(type, team, cell):
		return false
	spawn_building(type, team, cell, true)
	production[team].erase("building")
	return true


func remove_entity(e) -> void:
	entities.erase(e)
	_ids.erase(e.net_id)
	if game_over or not (e is Building) or Net.is_client():
		return # no convidado quem decide o fim da partida é o anfitrião
	var team: int = e.team
	if building_count(team) == 0:
		game_over = true
		game_ended.emit(team != local_team)
		Net.send_game_over(team)


## Mensagem para o dono do time: aparece aqui se for o jogador local; no multiplayer, o
## anfitrião repassa as do time do convidado.
func notify(team: int, text: String) -> void:
	if team == local_team:
		message.emit(text)
	elif Net.is_host():
		Net.send_message(text)


## Liga/desliga o conserto de um prédio (o convidado pede ao anfitrião).
func request_repair(b: Building, on: bool) -> void:
	if Net.is_client():
		Net.order("repair", [b.net_id, on])
	else:
		b.set_repairing(on)


func set_net_id(e, id: int) -> void:
	_ids.erase(e.net_id)
	e.net_id = id
	_ids[id] = e
	_next_id = maxi(_next_id, id + 1)


func by_id(id: int):
	var e = _ids.get(id)
	return e if is_instance_valid(e) and not e.dead else null


## Índice compacto de cada tipo de unidade/prédio (igual nos dois computadores).
func type_index(type: String) -> int:
	if _types.is_empty():
		_types = UNITS.keys() + BUILDINGS.keys()
		_types.sort()
	return _types.find(type)


func type_name(i: int) -> String:
	type_index("")
	return _types[i] if i >= 0 and i < _types.size() else ""


func spawn_explosion(pos: Vector2, size: float, height := 0.0, color := Color(1.0, 0.55, 0.2)) -> void:
	if world == null:
		return
	var fx := Explosion.new()
	fx.position = to3d(pos, height)
	fx.size = size
	fx.color = color
	fx.visible = fog == null or fog.is_visible_at(pos)  # não revela combates na névoa
	if fx.visible:
		Sfx.explosion(fx.position, size)
	world.add_child(fx)
