--[[
	A collection of functions that operate on Lua tables. These can operate on arrays,
	dictionaries and any collection types implemented with tables.

	Functions can also iterate over custom iterator functions.

	These functions typically act on immutable tables and return new tables in functional style.
	Note that mutable arguments in Rodash are explicitly typed as such.
]]
local t = require(script.Parent.t)

local Tables = {}

local function getIterator(source)
	if type(source) == "function" then
		return source
	else
		assert(type(source) == "table", "BadInput: Can only iterate over a table or an iterator function")
		return pairs(source)
	end
end

local function assertHandlerIsFn(handler)
	local Functions = require(script.Functions)
	assert(Functions.isCallable(handler), "BadInput: handler must be a function")
end

--[[
	Get a child or descendant of a table, returning nil if any errors are generated.
	@param key The key of the child.
	@param ... Further keys to address any descendent.
	@example
		local upperTorso = _.get(game.Players, "LocalPlayer", "Character", "UpperTorso")
		upperTorso --> Part (if player's character and its UpperTorso are defined)
	@example
		-- You can also bind a lookup to get later on:
		local getUpperTorso = _.bindTail(_.get, "Character", "UpperTorso")
		getUpperTorso(players.LocalPlayer) --> Part
	@trait Chainable
]]
--: <T: Iterable<K, V>>(T, ...K) -> V
function Tables.get(source, key, ...)
	local tailKeys = {...}
	local ok, value =
		pcall(
		function()
			return source[key]
		end
	)
	if ok then
		if #tailKeys > 0 then
			return Tables.get(value, unpack(tailKeys))
		else
			return value
		end
	end
end

--[[
	Return new table from _source_ with each value at the same key, but replaced by the return from
	the _handler_ function called for each value and key in the table.
	@example
		local playerNames = _.map(game.Players:GetChildren(), function(player)
			return player.Name
		end)
		playerNames --> {"Frodo Baggins", "Bilbo Baggins", "Boromir"}
	@example
		-- nil values naturally do not translate to keys:
		local balls = {
			{color: "red", amount: 0},
			{color: "blue", amount: 10},
			{color: "yellow", amount: 12}
		}
		local foundColors = _.map(balls, function(ball)
			return ball.amount > 0 and ball.color or nil
		end)
		foundColors --> {"blue", "yellow"}
	@example
		local numbers = {1, 1, 2, 3, 5} 
		local nextNumbers = _.map(numbers, function( value, key )
			return value + (numbers[key - 1] or 0)
		end)
		nextNumbers --> {1, 2, 3, 5, 8}
]]
--: <T: Iterable<K,V>, R: Iterable<K,V2>((T, (element: V, key: K) -> V2) -> R)
function Tables.map(source, handler)
	assertHandlerIsFn(handler)
	local result = {}
	for i, v in getIterator(source) do
		result[i] = handler(v, i)
	end
	return result
end

--[[
	Like `_.map`, but returns an array of the transformed values in the order that they are
	iterated over, dropping the original keys.
	@example
		local ingredients = {veg = "carrot", sauce = "tomato", herb = "basil"}
		local list = _.mapValues(function(value)
			return _.format("{} x2", value)
		end)
		list --> {"carrot x2", "tomato x2", "basil x2"} (in some order)
]]
--: <T: Iterable<K,V>, V2>((T, (element: V, key: K) -> V2) -> V2[])
function Tables.mapValues(source, handler)
	assertHandlerIsFn(handler)
	local result = {}
	for i, v in getIterator(source) do
		table.insert(result, handler(v, i))
	end
	return result
end

--[[
	Like `_.map`, but the return of the _handler_ is used to transform the key of each element,
	while the value is preserved.

	If the _handler_ returns nil, the element is dropped from the result.
	@example
		local playerSet = {Frodo = true, Bilbo = true, Boromir = true}
		local healthSet = _.keyBy(playerSet, function(name)
			return _.get(game.Players, name, "Health")
		end)
		healthSet --> {100 = true, 50 = true, 0 = true}
]]
--: <T: Iterable<K,V>, R: Iterable<K,V2>((T, (element: V, key: K) -> V2) -> R)
function Tables.keyBy(source, handler)
	assertHandlerIsFn(handler)
	local result = {}
	for i, v in getIterator(source) do
		local key = handler(v, i)
		if key ~= nil then
			result[key] = v
		end
	end
	return result
end

--[[
	Like `_.mapValues` but _handler_ must return an array. These elements are then insterted into
	the the resulting array returned.

	You can return an empty array `{}` from handler to avoid inserting anything for a particular
	element.

	@example
		local tools = _.flatMap(game.Players:GetChildren(), function(player)
			return player.Backpack:GetChildren()
		end)
		tools --> {Spoon, Ring, Sting, Book}
]]
--: <T: Iterable<K,V>, U>((T, (element: V, key: K) -> U[]) -> U[])
function Tables.flatMap(source, handler)
	assertHandlerIsFn(handler)
	local Arrays = require(script.Arrays)
	local result = {}
	for i, v in getIterator(source) do
		local list = handler(v, i)
		assert(t.table(list), "BadResult: Handler must return an array")
		Arrays.append(result, list)
	end
	return result
end

--[[
	Returns an array of any values in _source_ that the _handler_ function returned `true` for,
	in order of iteration.

	@example
		local myTools = game.Players.LocalPlayer.Backpack:GetChildren()
		local mySpoons = _.filter(myTools, function(tool)
			return _.endsWith(tool.Name, "Spoon")
		end)
		mySpoons --> {SilverSpoon, TableSpoon}
	@see _.filterKeys if you would like to filter but preserve table keys
]]
--: <T: Iterable<K,V>>(T, (element: V, key: K -> bool) -> V[])
function Tables.filter(source, handler)
	assertHandlerIsFn(handler)
	local result = {}
	for i, v in getIterator(source) do
		if handler(v, i) then
			table.insert(result, v)
		end
	end
	return result
end

--[[
	Returns a table of any elements in _source_ that the _handler_ function returned `true` for,
	preserving the key and value of every accepted element.
	@example
		local ingredients = {veg = "carrot", sauce = "tomato", herb = "basil"}
		local carrotsAndHerbs = _.filterKeys(ingredients, function( value, key )
			return value == "carrot" or key == "herb"
		end)
		carrotsAndHerbs --> {veg = "carrot", herb = "basil"}
]]
--: <T: Iterable<K,V>>(T, (element: V, key: K -> bool) -> T)
function Tables.filterKeys(source, handler)
	assertHandlerIsFn(handler)
	local result = {}
	for i, v in getIterator(source) do
		if handler(v, i) then
			result[i] = v
		end
	end
	return result
end

--[[
	Returns an array of elements in _source_ with any elements of _value_ removed.
	@example
		local points = {0, 10, 3, 0, 5}
		local nonZero = _.without(points, 0)
		nonZero --> {10, 3, 5}
	@example
		local ingredients = {veg = "carrot", sauce = "tomato", herb = "basil"}
		local withoutCarrots = _.without(ingredients, "carrot")
		withoutCarrots --> {"tomato", "basil"} (in some order)
]]
--: <T: Iterable<K,V>>(T, V -> V[])
function Tables.without(source, value)
	return Tables.filter(
		source,
		function(child)
			return child ~= value
		end
	)
end

--[[
	Returns an array of elements from a sparse array _source_ with the returned elements provided
	in original key-order.

	@example
		local names = {
			[3] = "Boromir",
			[1] = "Frodo",
			[8] = "Bilbo"
		}
		local inOrderNames = _.compact(names)
		inOrderNames --> {"Frodo", "Boromir", "Bilbo"}
]]
--: <T: Iterable<K,V>>(T -> V[])
function Tables.compact(source)
	local Arrays = require(script.Arrays)
	local sortedKeys = Arrays.sort(Tables.keys(source))
	return Tables.map(
		sortedKeys,
		function(key)
			return source[key]
		end
	)
end

--[[
	Return `true` if _handler_ returns true for every element in _source_ it is called with.

	If no handler is provided, `_.all` returns true if every element is non-nil.
	@param handler (default = `_.id`)
	@example
		local names = {
			[3] = "Boromir",
			[1] = "Frodo",
			[8] = "Bilbo"
		}
		local allNamesStartWithB = _.all(names, function(name)
			return _.startsWith(name, "B")
		end)
		allNamesStartWithB --> false
]]
--: <T: Iterable<K,V>>(T, (value: V, key: K -> bool)?) -> bool
function Tables.all(source, handler)
	if not handler then
		handler = function(x)
			return x
		end
	end
	assertHandlerIsFn(handler)
	-- Use double negation to coerce the type to a boolean, as there is
	-- no toboolean() or equivalent in Lua.
	return not (not Tables.reduce(
		source,
		function(acc, value, key)
			return acc and handler(value, key)
		end,
		true
	))
end

--[[
	Return `true` if _handler_ returns true for at least one element in _source_ it is called with.

	If no handler is provided, `_.any` returns true if some element is non-nil.
	@param handler (default = `_.id`)
	@example
		local names = {
			[3] = "Boromir",
			[1] = "Frodo",
			[8] = "Bilbo"
		}
		local anyNameStartsWithB = _.any(names, function(name)
			return _.startsWith(name, "B")
		end)
		anyNameStartsWithB --> true
]]
--: <T: Iterable<K,V>>(T -> bool)
function Tables.any(source, handler)
	if not handler then
		handler = function(x)
			return x
		end
	end
	assertHandlerIsFn(handler)
	-- Use double negation to coerce the type to a boolean, as there is
	-- no toboolean() or equivalent in Lua.
	return not (not Tables.reduce(
		source,
		function(acc, value, key)
			return acc or handler(value, key)
		end,
		false
	))
end

--[[
	Returns a copy of _source_, ensuring each key starts with an underscore `_`.
	Keys which are already prefixed with an underscore are left unchanged.
	@example
		local privates = _.privatize({
			[1] = 1,
			public = 2,
			_private = 3
		})
		privates --> {_1 = 1, _public = 2, _private = 3}
]]
-- <T>(T{} -> T{})
function Tables.privatize(source)
	local Strings = require(script.Strings)
	return Tables.keyBy(
		source,
		function(_, key)
			local stringKey = tostring(key)
			return Strings.startsWith(stringKey, "_") and stringKey or "_" .. stringKey
		end
	)
end

--[[
	Returns a table with elements from _source_ with their keys and values flipped.
	@example
		local teams = {red = "Frodo", blue = "Bilbo", yellow = "Boromir"}
		local players = _.invert(teams)
		players --> {Frodo = "red", Bilbo = "blue", Boromir = "yellow"}
]]
--: <K: Key, V>(Iterable<K,V> -> Iterable<V,K>)
function Tables.invert(source)
	local result = {}
	for i, v in getIterator(source) do
		result[v] = i
	end
	return result
end

--[[
	Like `_.map`, but the return of the _handler_ is used to transform the key of each element,
	while the value is preserved.

	If the _handler_ returns nil, the element is dropped from the result.
	@example
		local playerSet = {Frodo = true, Bilbo = true, Boromir = true}
		local healthSet = _.mapKeys(playerSet, function(name)
			return _.get(game.Players, name, "Health")
		end)
		healthSet --> {100 = true, 50 = true, 0 = true}
]]
--: <T: Iterable<K,V>, I: Key>((value: T, key: K) -> I) -> Iterable<I, Iterable<K,V>>)
function Tables.groupBy(source, handler)
	assertHandlerIsFn(handler)
	local result = {}
	for i, v in getIterator(source) do
		local key = handler(v, i)
		if key ~= nil then
			if not result[key] then
				result[key] = {}
			end
			table.insert(result[key], v)
		end
	end
	return result
end

--[=[
	Mutates _target_ by iterating recursively through elements of the subsequent
	arguments in order and inserting or replacing the values in target with each
	element preserving keys.

	If any values are both tables, these are merged recursively using `_.merge`.
	@example
		local someInfo = {
			Frodo = {
				name = "Frodo Baggins",
				team = "blue"
			},
			Boromir = {
				score = 5
			}
		}
		local someOtherInfo = {
			Frodo = {
				team = "red",
				score = 10
			},
			Bilbo = {
				team = "yellow",

			},
			Boromir = {
				score = {1, 2, 3}
			}
		}
		local mergedInfo = _.merge(someInfo, someOtherInfo)
		--[[
			--> {
				Frodo = {
					name = "Frodo Baggins",
					team = "red",
					score = 10
				},
				Bilbo = {
					team = "yellow"
				},
				Boromir = {
					score = {1, 2, 3}
				}
			}
		]]
	@see _.assign
	@see _.defaults
]=]
--: <T: Iterable<K,V>>(mut T, ...T) -> T
function Tables.merge(target, ...)
	-- Use select here so that nil arguments can be supported. If instead we
	-- iterated over ipairs({...}), any arguments after the first nil one
	-- would be ignored.
	for i = 1, select("#", ...) do
		local source = select(i, ...)
		if source ~= nil then
			for key, value in getIterator(source) do
				if type(target[key]) == "table" and type(value) == "table" then
					target[key] = Tables.merge(target[key] or {}, value)
				else
					target[key] = value
				end
			end
		end
	end
	return target
end

--[[
	Returns an array of all the values of the elements in _source_.
	@example _.values({
		Frodo = 1,
		Boromir = 2,
		Bilbo = 3
	}) --> {1, 2, 3} (in some order)
]]
--: <T: Iterable<K,V>>(T -> V[])
function Tables.values(source)
	local result = {}
	for i, v in getIterator(source) do
		table.insert(result, v)
	end
	return result
end

--[[
	Returns an array of all the keys of the elements in _source_.
	@example _.values({
		Frodo = 1,
		Boromir = 2,
		Bilbo = 3
	}) --> {"Frodo", "Boromir", "Bilbo"} (in some order)
]]
--: <T: Iterable<K,V>>(T -> K[])
function Tables.keys(source)
	local result = {}
	for i, v in getIterator(source) do
		table.insert(result, i)
	end
	return result
end

--[[
	Returns an array of all the entries of elements in _source_.

	Each entry is a tuple `(key, value)`.

	@example _.values({
		Frodo = 1,
		Boromir = 2,
		Bilbo = 3
	}) --> {{"Frodo", 1}, {"Boromir", 2}, {"Bilbo", 3}} (in some order)
]]
--: <T: Iterable<K,V>>(T -> {K, V}[])
function Tables.entries(source)
	local result = {}
	for i, v in getIterator(source) do
		table.insert(result, {i, v})
	end
	return result
end

--[[
	Picks a value from the table that _handler_ returns `true` for.

	As tables do not have ordered keys, do not rely on returning any particular value.
	@example
		local names = {
			[3] = "Boromir",
			[1] = "Frodo",
			[8] = "Bilbo"
		}
		local nameWithB = _.find(names, function(name)
			return _.startsWith(name, "B")
		end)
		nameWithB --> "Bilbo", 8 (or "Boromir", 3)

		-- Or use a chain:
		local nameWithF = _.find(names, _.fn:startsWith(name, "B"))
		nameWithF --> "Frodo", 1

		-- Or find the key of a specific value:
		local _, key = _.find(names, _.fn:matches("Bilbo"))
		key --> 8
	@see _.first
	@usage If you need to find the first value of an array that matches, use `_.first`.
]]
--: <T: Iterable<K,V>>((T, (element: V, key: K) -> bool) -> V?)
function Tables.find(source, handler)
	assertHandlerIsFn(handler)
	for i, v in getIterator(source) do
		if (handler(v, i)) then
			return v, i
		end
	end
end

--[[
	Returns `true` if _item_ exists as a value in the _source_ table.
	@example
		local names = {
			[3] = "Boromir",
			[1] = "Frodo",
			[8] = "Bilbo"
		}
		_.includes(names, "Boromir") --> true
		_.includes(names, 1) --> false
]]
--: <T: Iterable<K,V>>(T, V -> bool)
function Tables.includes(source, item)
	return Tables.find(
		source,
		function(value)
			return value == item
		end
	) ~= nil
end

--[[
	Returns the number of elements in _source_.
	@example
		local names = {
			[3] = "Boromir",
			[1] = "Frodo",
			[8] = "Bilbo"
		}
		_.len(names) --> 3
]]
--: <T: Iterable<K,V>>(T -> int)
function Tables.len(source)
	local count = 0
	for _ in pairs(source) do
		count = count + 1
	end
	return count
end

local function assign(shouldOverwriteTarget, target, ...)
	-- Use select here so that nil arguments can be supported. If instead we
	-- iterated over ipairs({...}), any arguments after the first nil one
	-- would be ignored.
	for i = 1, select("#", ...) do
		local source = select(i, ...)
		if source ~= nil then
			for key, value in getIterator(source) do
				if shouldOverwriteTarget or target[key] == nil then
					target[key] = value
				end
			end
		end
	end
	return target
end

--[=[
	Adds new elements in _target_ from subsequent table arguments in order, with elements in later
	tables replacing earlier ones if their keys match.
	@param ... any number of other tables
	@example
		local someInfo = {
			Frodo = {
				name = "Frodo Baggins",
				team = "blue"
			},
			Boromir = {
				score = 5
			}
		}
		local someOtherInfo = {
			Frodo = {
				team = "red",
				score = 10
			},
			Bilbo = {
				team = "yellow",

			},
			Boromir = {
				score = {1, 2, 3}
			}
		}
		local assignedInfo = _.assign(someInfo, someOtherInfo)
		--[[
			--> {
				Frodo = {
					team = "red",
					score = 10
				},
				Bilbo = {
					team = "yellow"
				},
				Boromir = {
					score = {1, 2, 3}
				}
			}
		]]
	@see _.defaults
	@see _.merge
]=]
--: <T: Iterable<K,V>>(mut T, ...T) -> T
function Tables.assign(target, ...)
	return assign(true, target, ...)
end

--[=[
	Adds new elements in _target_ from subsequent table arguments in order, with elements in
	earlier tables replacing earlier ones if their keys match.
	@param ... any number of other tables
	@example
		local someInfo = {
			Frodo = {
				name = "Frodo Baggins",
				team = "blue"
			},
			Boromir = {
				score = 5
			}
		}
		local someOtherInfo = {
			Frodo = {
				team = "red",
				score = 10
			},
			Bilbo = {
				team = "yellow",

			},
			Boromir = {
				score = {1, 2, 3}
			}
		}
		local assignedInfo = _.assign(someInfo, someOtherInfo)
		--[[
			--> {
				Frodo = {
					name = "Frodo Baggins",
					team = "blue"
				},
				Boromir = {
					score = 5
				}
				Bilbo = {
					team = "yellow"
				}
			}
		]]
	@see _.assign
	@see _.merge
]=]
--: <T: Iterable<K,V>>(mut T, ...T) -> T
function Tables.defaults(target, ...)
	return assign(false, target, ...)
end

--[[
	Returns a shallow copy of _source_.
	@example
		local Hermione = {
			name = "Hermione Granger",
			time = 12
		}
		local PastHermione = _.clone(Hermione)
		PastHermione.time = 9
		Hermione.time --> 12
	@see _.cloneDeep
	@see _.Clone
	@usage If you also want to clone children of the table you may want to use or `_.cloneDeep` but this can be costly.
	@usage To change behaviour for particular values use `_.map` with a handler.
	@usage Alternatively, if working with class instances see `_.Clone`.
]]
--: <T: Iterable<K,V>>(T -> T)
function Tables.clone(source)
	return Tables.assign({}, source)
end

--[[
	Returns `true` if all the values in _a_ match corresponding values in _b_ recursively.

	* For elements which are not tables, they match if they are equal.
	* If they are tables they match if the right is a subset of the left.

	@example
		local car = {
			speed = 10,
			wheels = 4,
			lightsOn = {
				indicators = true,
				headlights = false
			}
		}
		_.isSubset(car, {}) --> true
		_.isSubset(car, car) --> true
		_.isSubset(car, {speed = 10, lightsOn = {indicators = true}}) --> true
		_.isSubset(car, {speed = 12}) --> false
		_.isSubset({}, car) --> false
]]
-- <T: Iterable<K,V>>(T, any -> bool)
function Tables.isSubset(a, b, references)
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	else
		for key, aValue in pairs(a) do
			local bValue = b[key]
			if type(aValue) ~= type(bValue) then
				return false
			elseif aValue ~= bValue then
				if type(aValue) == "table" then
					-- The values are tables, so we need to recurse for a deep comparison.
					if not Tables.isSubset(aValue, bValue) then
						return false
					end
				else
					return false
				end
			end
		end
	end
	return true
end

--[[
	Returns `true` if _source_ has no keys.
	@example
		_.isEmpty({}) --> true
		_.isEmpty({false}) --> false
		_.isEmpty({a = 1}) --> false
]]
--: <T: Iterable<K,V>>(T -> bool)
function Tables.isEmpty(source)
	return getIterator(source)(source) == nil
end

--[[
	Returns an element from _source_, if it has one.
	@example
		_.one({}) --> nil
		_.one({a = 1, b = 2, c = 3}) --> b, 2 (or any another element)
]]
--: <T: Iterable<K,V>>(T -> (V, K)?)
function Tables.one(source)
	local key, value = getIterator(source)(source)
	return value, key
end

--[[
	Returns `true` if every element in _a_ recursively matches every element _b_.

	* For elements which are not tables, they match if they are equal.
	* If they are tables they match if the left is recursively deeply-equal to the right.

	@example
		local car = {
			speed = 10,
			wheels = 4,
			lightsOn = {
				indicators = true,
				headlights = false
			}
		}
		local car2 = {
			speed = 10,
			wheels = 4,
			lightsOn = {
				indicators = false,
				headlights = false
			}
		}
		_.deepEqual(car, {}) --> false
		_.deepEqual(car, car) --> true
		_.deepEqual(car, _.clone(car)) --> true
		_.deepEqual(car, _.cloneDeep(car)) --> true
		_.deepEqual(car, car2) --> false
	@see _.isSubset
	@see _.shallowEqual
]]
function Tables.deepEqual(a, b)
	return Tables.isSubset(a, b) and Tables.isSubset(b, a)
end

--[[
	Returns `true` if _left_ and _right_ are equal, or if they are tables and the elements in one
	are present and have equal values to those in the other.
	@example
		local car = {
			speed = 10,
			wheels = 4,
			lightsOn = {
				indicators = true,
				headlights = false
			}
		}
		_.shallowEqual(car, {}) --> false
		_.shallowEqual(car, car) --> true
		_.shallowEqual(car, _.clone(car)) --> true
		_.shallowEqual(car, _.cloneDeep(car)) --> false

	Based on https://developmentarc.gitbooks.io/react-indepth/content/life_cycle/update/using_should_component_update.html
	@see _.deepEqual
]]
function Tables.shallowEqual(left, right)
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	local leftKeys = Tables.keys(left)
	local rightKeys = Tables.keys(right)
	if #leftKeys ~= #rightKeys then
		return false
	end
	return Tables.all(
		left,
		function(value, key)
			return value == right[key]
		end
	)
end

--[[
	Returns `true` is _source_ is made up only of natural keys `1..n`.
	@example
		_.isArray({1, 2, 3}) --> true
		_.isArray({a = 1, b = 2, c = 3}) --> false
		-- Treating sparse arrays as natural arrays will only complicate things:
		_.isArray({1, 2, nil, nil, 3}) --> false
		_.isArray(_.compact({1, 2, nil, nil, 3})) --> true
]]
--: <T: Iterable<K,V>>(T -> bool)
function Tables.isArray(source)
	return #Tables.keys(source) == #source
end

local function serializeVisit(source, valueSerializer, keySerializer, cycles)
	local Arrays = require(script.Arrays)
	local isArray = Tables.isArray(source)
	local ref = ""
	if cycles.refs[source] then
		if cycles.visits[source] then
			return "&" .. cycles.visits[source]
		else
			cycles.count = cycles.count + 1
			cycles.visits[source] = cycles.count
			ref = "<" .. cycles.count .. ">"
		end
	end
	local contents =
		table.concat(
		Tables.map(
			Arrays.sort(Tables.keys(source)),
			function(key)
				local value = source[key]
				local stringValue = valueSerializer(value, cycles)
				return isArray and stringValue or keySerializer(key, cycles) .. ":" .. stringValue
			end
		),
		","
	)
	return ref .. "{" .. contents .. "}"
end

--[[
	Returns a string representation of _source_ including all elements with sorted keys.
	
	`_.serialize` preserves the properties of being unique, stable and cycle-safe if the serializer
	functions provided also obey these properties.

	@param valueSerializer (default = `_.defaultSerializer`) return a string representation of a value
	@param keySerializer (default = `_.defaultSerializer`) return a string representation of a value

	@example _.serialize({1, 2, 3}) --> "{1,2,3}"
	@example _.serialize({a = 1, b = true, [3] = "hello"}) --> '{"a":1,"b":true,3:"hello"}'
	@example 
		_.serialize({a = function() end, b = {a = "table"})
		--> '{"a":<function: 0x...>,"b"=<table: 0x...>}'
	@usage Use `_.serialize` when you need a representation of a table which doesn't need to be
		human-readable, or you need to customize the way serialization works. `_.pretty` is more
		appropriate when you need a human-readable string.
	@see _.serializeDeep
	@see _.defaultSerializer
	@see _.pretty
]]
--: <T: Iterable<K,V>>(T, (V, Cycles<V> -> string), (K, Cycles<V> -> string) -> string)
function Tables.serialize(source, valueSerializer, keySerializer)
	valueSerializer = valueSerializer or Tables.defaultSerializer
	keySerializer = keySerializer or Tables.defaultSerializer
	local Functions = require(script.Functions)
	assert(Functions.isCallable(valueSerializer), "BadInput: valueSerializer must be a function if defined")
	assert(Functions.isCallable(keySerializer), "BadInput: keySerializer must be a function if defined")
	-- Find tables which appear more than once, and assign each an index
	local tableRefs =
		Tables.map(
		Tables.occurences(source),
		function(value)
			return value > 1 and value or nil
		end
	)
	local cycles = {
		refs = tableRefs,
		count = 0,
		visits = {}
	}
	return serializeVisit(source, valueSerializer, keySerializer, cycles)
end

--[[
	Like `_.serialize`, but if a child element is a table it is serialized recursively.

	Returns a string representation of _source_ including all elements with sorted keys.
	
	This function preserves uniqueness, stability and cycle-safety.

	@param valueSerializer (default = `_.defaultSerializer`) return a string representation of a value
	@param keySerializer (default = `_.defaultSerializer`) return a string representation of a value

	@example 
		_.serializeDeep({a = {b = "table"}) --> '{"a":{"b":"table"}}'
	@example 
		local kyle = {name = "Kyle"}
		kyle.child = kyle
		_.serializeDeep(kyle) --> '<0>{"child":<&0>,"name":"Kyle"}'
	@see _.serialize
	@see _.defaultSerializer
]]
--: <T: Iterable<K,V>>(T, (V, Cycles<V> -> string), (K, Cycles<V> -> string) -> string)
function Tables.serializeDeep(source, serializer, keySerializer)
	serializer = serializer or Tables.defaultSerializer
	keySerializer = keySerializer or Tables.defaultSerializer
	local Functions = require(script.Functions)
	assert(Functions.isCallable(serializer), "BadInput: serializer must be a function if defined")
	assert(Functions.isCallable(keySerializer), "BadInput: keySerializer must be a function if defined")
	local function deepSerializer(value, cycles)
		if type(value) == "table" then
			return serializeVisit(value, deepSerializer, keySerializer, cycles)
		else
			return serializer(value, cycles)
		end
	end
	return Tables.serialize(source, deepSerializer, keySerializer)
end

--[[
	A function which provides a simple, shallow string representation of a value.
]]
function Tables.defaultSerializer(input)
	if input == nil then
		return "nil"
	elseif type(input) == "number" or type(input) == "boolean" then
		return tostring(input)
	elseif type(input) == "string" then
		return '"' .. input:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
	else
		return "<" .. tostring(input) .. ">"
	end
end

local function countOccurences(source, counts)
	for key, value in getIterator(source) do
		if type(value) == "table" then
			if counts[value] then
				counts[value] = counts[value] + 1
			else
				counts[value] = 1
				countOccurences(value, counts)
			end
		end
	end
end

--[[
	Return a set of the tables that appear as descendants of _source_, mapped to the number of
	times each table has been found with a unique parent.

	Repeat occurences are not traversed, so the function is cycle-safe. If any tables in the
	result have a count of two or more, they may form cycles in the _source_.
	@example
		local plate = {veg = "potato", pie = {"stilton", "beef"}}
		_.census(plate) --> {
			[{veg = "potato", pie = {"stilton", "beef"}}] = 1
			[{"stilton", "beef"}] = 1
		}
	@example
		local kyle = {name = "Kyle"}
		kyle.child = kyle
		_.census(kyle) --> {
			[{name = "Kyle", child = kyle}] = 2
		}
]]
-- <T: Iterable<K,V>>(T -> Iterable<T,int>)
function Tables.occurences(source)
	assert(t.table(source), "BadInput: source must be a table")
	local counts = {[source] = 1}
	countOccurences(source, counts)
	return counts
end

--[[
	Returns an array of the values in _source_, without any repetitions.

	Values are considered equal if the have the same key representation.

	@example
		local list = {1, 2, 2, 3, 5, 1}
		_.unique(list) --> {1, 2, 3, 5} (or another order)
]]
function Tables.unique(source)
	return Tables.keys(Tables.invert(source))
end

return Tables
