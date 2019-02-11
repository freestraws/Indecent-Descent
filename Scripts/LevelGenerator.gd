extends Node

var Multimap = load("res://Scripts/Multimap.gd")
var map = Multimap.new()
var Tile = load("res://Scenes/Tile.tscn")
var Gap = load("res://Scenes/Gap.tscn")
var Collectible = load("res://Scenes/Collectible.tscn")
var Walls = load("res://Scenes/Walls.tscn")
var min_path_length = 15
var max_path_length = 20
var initial_enemy_chance = 0.05
var enemy_chance
var forbidden_directions = []
var has_passed_min = false
export(int) var width = 20
export(int) var length = 20
export(int) var wall_height = 10

var level_queue_height = 6
var num_level = 0
var level_queue = []
var top_y = 0

func _ready():
	enemy_chance = initial_enemy_chance
	randomize()
	map_it()
	for i in range(level_queue_height):
		level_queue.push_back($LevelGenerator.new_level(num_level))
		num_level+=1

func queue_Delete_One_Add_One():
	var dequeued = level_queue.pop_front()
	
	dequeued.queue_free()
	level_queue.push_back(new_level())
	top_y = level_queue.front().get_translation().y
	num_level += 1
	return num_level

func new_level():
	var level = Spatial.new()
	add_child(level)
	level.set_translation(Vector3(0, -(wall_height*num_level), 0))
	level.name = "Level " + str(num_level)
	print("\n" +level.name)
	var tiles = Spatial.new()
	tiles.name = "tiles"
	level.add_child(tiles)
	
	var path = createString("S")
	$PathBuilder.set_translation(Vector3(0,0,0))
	buildPath(path, tiles, width, length)
	
	var walls = Walls.instance()
	level.add_child(walls)
	walls.makeWalls(wall_height, width, length)
	shift_to_center(tiles)
	return level

# adds all the keys/ operators in the grammar (with values and weights) to the multimap
func map_it():
	var tileTypes = []
	var tileWeights = []
	tileTypes.append("n")
	tileTypes.append("s")
	tileTypes.append("i")
	tileTypes.append("c")

	tileWeights.append(0.65)
	tileWeights.append(0.10)
	tileWeights.append(0.10)
	tileWeights.append(0.15)
	map.append('T', tileTypes, tileWeights)

	var directionOptions = []
	var directionWeights = []
	directionOptions.append("u")
	directionOptions.append("d")
	directionOptions.append("l")
	directionOptions.append("r")

	directionWeights.append(0.33)
	directionWeights.append(0.33)
	directionWeights.append(0.17)
	directionWeights.append(0.17)
	map.append('D', directionOptions, directionWeights)

	var pathOptions = []
	var pathWeights = []
	pathOptions.append("KDP")
	pathOptions.append("KJ")
	pathOptions.append("KGKDP")

	pathWeights.append(0.4)
	pathWeights.append(0.3)
	pathWeights.append(0.3)
	map.append('P', pathOptions, pathWeights)

	var junctionOptions = []
	var junctionWeights = []
	junctionOptions.append("(DP.DP)")
	junctionOptions.append("(DP.DP.DP)")

	junctionWeights.append(0.5)
	junctionWeights.append(0.5)
	map.append('J', junctionOptions, junctionWeights)

	var tileCollectOptions = []
	var tileCollectWeights = []
	tileCollectOptions.append("Tx")
	tileCollectOptions.append("T")

	tileCollectWeights.append(0.05)
	tileCollectWeights.append(0.95)
	map.append('K', tileCollectOptions, tileCollectWeights)

	var gapOptions = []
	var gapWeights = []
	gapOptions.append("gx")
	gapOptions.append("g")

	gapWeights.append(0.20)
	gapWeights.append(0.80)
	map.append('G', gapOptions, gapWeights)

	var startOptions = []
	startOptions.append("nDP")
	map.append('S', startOptions)


	

# return a bool based on whether the string has only characters that correspond to terminal
# operators in the level gen grammar
func isKeyFullOfTerminals(key):
	for c in key:
		if (!isTerminal(c)):
			return false
	return true
	
func isTerminal(c):
	return (is_lower(c) || c == '(' || c == ')' || c == '.')

func is_lower(c):
	return c.to_ascii()[0] >=97 and c.to_ascii()[0]<=122

func isTile(c):
	return (c == 'n' || c == 'i' || c == 's' || c == 'c' || c == 'g')

# make by parsing key out to what it should be based on the multimap
func createString(key):
	var pathLength = 1
	# make sure the path doesn't go on forever
	while(pathLength < max_path_length && !isKeyFullOfTerminals(key)):
		key = parseIt(key)
		for c in key:
			if(c == 'P'):
				pathLength+=1
			elif(c == 'G'):
				pathLength+=2
		if(!has_passed_min && pathLength > min_path_length):
			var newPathWeights = []
			newPathWeights.append(0.3)
			newPathWeights.append(0.25)
			newPathWeights.append(0.25)
			newPathWeights.append(0.2)
			map.addNewValueToKey('P', "K", newPathWeights)
			has_passed_min = true

	while(!isKeyFullOfTerminals(key)):
		key = wrapup(key)
	
	print("key: "+str(key)+", length: "+str(pathLength))
	return key

# once max path length is reached this is called to just make sure that any non-terminal operators
# still in the string get turned into something (a tile)
func wrapup(string):
	var i = ""
	for c in string:
		if(isTerminal(c)):
			i += c
		elif(c == 'P'):
			i += map.get_random_map_value('K')
		elif(c != 'J'):
			i += map.get_random_map_value(c)
	return i

# get a string, return whatever it would be according to multimap
# special cases for junctions and directions
func parseIt(string):
	var i = ""
	for c in string:
		if(isTerminal(c)):
			match c:
				'u':
					if forbidden_directions.size()>0: forbidden_directions.pop_front()
					forbidden_directions.push_front("d")
				'd':
					if forbidden_directions.size()>0: forbidden_directions.pop_front()
					forbidden_directions.push_front("u")
				'r':
					if forbidden_directions.size()>0: forbidden_directions.pop_front()
					forbidden_directions.push_front("l")
				'l':
					if forbidden_directions.size()>0: forbidden_directions.pop_front()
					forbidden_directions.push_front("r")
			i += c
		else:
			if(c == 'D'):
				var dir = map.get_random_map_value(c)
				while(forbidden_directions.has(dir)):
					dir = map.get_random_map_value(c)
				match dir:
					"u":
						if(forbidden_directions.size()>0): forbidden_directions.pop_front()
						forbidden_directions.push_front("d")
					"d":
						if(forbidden_directions.size()>0): forbidden_directions.pop_front()
						forbidden_directions.push_front("u")
					"r":
						if(forbidden_directions.size()>0): forbidden_directions.pop_front()
						forbidden_directions.push_front("l")
					"l":
						if(forbidden_directions.size()>0): forbidden_directions.pop_front()
						forbidden_directions.push_front("r")
				i+= dir
			else:
				var nextPath = map.get_random_map_value(c)
				if(nextPath == "KJ"):
					var junction = map.get_random_map_value('J')
					if(junction.length() <= 7): # 2 way junction
						var dir0 = map.get_random_map_value('D')
						while(forbidden_directions.has(dir0)):
							dir0 = map.get_random_map_value('D')
						forbidden_directions.push_front(dir0)

						var dir1 = map.get_random_map_value('D')
						while(forbidden_directions.has(dir1)):
							dir1 = map.get_random_map_value('D')
						i += "K("+dir0+"P."+dir1+"P)"
						forbidden_directions.pop_front()
						forbidden_directions.pop_front()
					else: # 3 way junction
						var dir0 = map.get_random_map_value('D')
						while(forbidden_directions.has(dir0)):
							dir0 = map.get_random_map_value('D')
						
						forbidden_directions.push_front(dir0)

						var dir1 = map.get_random_map_value('D')
						while(forbidden_directions.has(dir1)):
							dir1 = map.get_random_map_value('D')
						
						forbidden_directions.push_front(dir1)

						var dir2 = map.get_random_map_value('D')
						while(forbidden_directions.has(dir2)):
							dir2 = map.get_random_map_value('D')
						
						i += "K("+dir0+"P."+dir1+"P."+dir2+"P)"
						forbidden_directions.pop_front()
						forbidden_directions.pop_front()
						forbidden_directions.pop_front()
					
				
				elif(nextPath == "KGKDP"):
					var dir = map.get_random_map_value('D')
					while (forbidden_directions.has(dir)):
						dir = map.get_random_map_value('D')
					
					i += "KGK" + dir + "P"
				
				else :
					i+=nextPath
	return i

func is_within_bounds(x, z, bound_width, bound_length):
	return (x < (bound_width/2) and x > -(bound_width/2) and z < (bound_length/2) and z > -(bound_length/2))
# build the path and put the resulting tiles inside of the parent transform
func buildPath(fullString, parent, width, length):
	var dir = Vector3(0, 0, 0)
	var pathStack = []
	var spawned_locations = []
	var fails = 0
	for i in range(fullString.length()):
		var c = fullString[i]
		if(isTile(c)):
			var boxScale = Vector3(0.25, 0.25, 0.25)
			var can_place = false
			var path_loc = $PathBuilder.get_translation()
			while not can_place and is_within_bounds(path_loc.x, path_loc.z, width, length):
				if path_loc in spawned_locations:
					$PathBuilder.translate(dir)
					path_loc = $PathBuilder.get_translation()
				else:
					can_place = true
			if can_place:
				spawned_locations.append($PathBuilder.get_translation())
				var type = ""
				match c:
					'n': type = "normal"
					'c': type = "cracked"
					'i': type = "ice"
					's': type = "sticky"
					'g':
						$PathBuilder.translate(dir)
						var gap = Gap.instance()
						gap.set_translation($PathBuilder.get_translation())
						parent.add_child(gap)
						if (i + 1 < fullString.length() && fullString[i + 1] == 'x'):
							print("SPAWNING GAP COLLECTIBLE")
							var collectible = Collectible.instance()
							collectible.set_translation($PathBuilder.get_translation()+Vector3(0, 1, 0))
							parent.add_child(collectible)
							i+=1
						else:
							print("PLACING GAP")
						$PathBuilder.translate(dir)
				if type != "":
					var tile = Tile.instance()
					tile.set_translation($PathBuilder.get_translation())
					tile.set_type(type)
					tile.name = type
					parent.add_child(tile)
			else:
				print("couldn't place " + c)
		else:
			match c:
				'u':
					dir = Vector3(0, 0, 1)
					$PathBuilder.translate(dir)
				'd':
					dir = Vector3(0, 0, -1)
					$PathBuilder.translate(dir)
				'l':
					dir = Vector3(-1, 0, 0)
					$PathBuilder.translate(dir)
				'r':
					dir = Vector3(1, 0, 0)
					$PathBuilder.translate(dir)
				'x':
					var collectible = Collectible.instance()
					collectible.set_translation($PathBuilder.get_translation()+Vector3(0, 1, 0))
					parent.add_child(collectible)
				'(':
					pathStack.push_front($PathBuilder.get_translation())
				'.':
					$PathBuilder.set_translation(pathStack.front())
				')':
					pathStack.pop_front()

# shift the tiles to be centered within the walls
func shift_to_center(tiles):
	var smallestX = tiles.get_child(0).get_translation().x
	var smallestZ = tiles.get_child(0).get_translation().z
	var largestX = tiles.get_child(0).get_translation().x
	var largestZ = tiles.get_child(0).get_translation().z

	for i in range(tiles.get_child_count()):
		var child_pos = tiles.get_child(i).get_translation()
		if(child_pos.x < smallestX):
			smallestX = child_pos.x
		if(child_pos.z < smallestZ):
			smallestZ = child_pos.z
		if(child_pos.x > largestX):
			largestX = child_pos.x
		if(child_pos.z > largestZ):
			largestZ = child_pos.z
	
	var midX = (smallestX + largestX)/2

	var midZ = (smallestZ + largestZ)/2

	tiles.translate(Vector3(-midX, 0, -midZ))

# spawn enemies on the given level
#func spawnEnemies(level):
#	var tempEnemyChance = enemyChance
#	var thisRandom = randf()
#	while(thisRandom < tempEnemyChance):
#		var wall = (randi()%5) -1
#		var y = (-wall_height * num_level) + 1
#		var x = width / 2
#		var z = length / 2
#		match wall:
#			# North wall
#			0:
#				x = rand_range(-width / 2, width / 2)
#			# East wall
#			1:
#				z = rand_range(-width / 2, width / 2)
#			# South wall
#			2:
#				z = -z
#				x = rand_range(-width / 2, width / 2)
#			# West wall
#			3:
#				x = -x
#				z = rand_range(-width / 2, width / 2)
#		var enemyPos = Vector3(x, y, z)
#		var enemy = Enemy.instance()
#		enemy.set_translation(enemyPos)
#		level.add_child(enemy)
#		tempEnemyChance -= thisRandom
#		thisRandom = randf()