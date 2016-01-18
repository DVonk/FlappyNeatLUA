Inputs = 3; -- the amount of inputs
Outputs = 1; -- the amount of outputs

Population = 25; -- the amount of networks/genomes
MaxNodes = 300; -- the maximal amount of nodes

-- Werte sind placeholder
WeightMutChance = 0.25;
NewWeightChance = 0.1;
WeightLrngRate = 0.1;
NewConnectChance = 2.0;
NewNodeChance = 0.7;
DisableChance = 0.4;
EnableChance = 0.2;
ChanceCrossover = 0.6;
CoeffDisjointExcess = 1.0;
CoeffWeightDiff = 0.4;
DistanceTresh = 3.0;



innovation = Inputs; -- innovation at start
maxnode = Inputs; -- max node, excluding the ouput node, at start

function getInputs()
	local inputs = {}; -- input array
	inputs[1] = memory.readbyte(0x0B); -- height of the bird	
	inputs[2] = memory.readbyte(0x24); -- height of the pipe
	inputs[3] = memory.readbyte(0x04); -- distance to pipe
	
	return inputs;
end

function sigmoid(x) 
    return 1 / (1 + math.exp(x));
end

function shiftedSigmoid(x)
	return 2 * sigmoid(x) - 1;
end

function newNode() 
	local node = {}; -- a neuron/node
	node.inps = {}; -- the connections to input neurons
	node.value = 0.0; -- the value of the neuron
	node.rank = 0; -- used for output-calculation
	node.ancestors = {}; -- used to calculate the rank
	
	return node;
end

function newConnect()
	local connect = {}; -- a connection between neurons
	connect.inp = 0; -- the input neuron
	connect.outp = 0; -- the output neuron
	connect.weight = 0.0; -- the weight
	connect.enabled = true; -- connection enabled or disabled
	connect.innov = 0; -- historical marking
	
	return connect;
end

function copyConnect(connect)
	local connectCopy = newConnect(); -- the copy of an existing connection
	connectCopy.inp = connect.inp;
	connectCopy.outp = connect.outp;
	connectCopy.weight = connect.weight;
	connectCopy.enabled = connect.enabled;
	connectCopy.innov = connect.innov;
	
	return connectCopy;
end

function connectExists(connectList, connect)
	for i = 1, #connectList do
		local connect2 = connectList[i];
		if connect2.inp == connect.inp and connect2.outp == connect.outp then
			return true;
		end
	end
	return false;
end

function newGenome()
	local genome = {} -- a genome
	genome.connections = {}; -- the connections of the genome
	genome.network = {}; -- the coresponding network/phenotype
	genome.fitness = 0; -- the fitness of the genome
	genome.numConnects = 0;
	genome.numNodes = 0;
	
	return genome;
end

function copyGenome(genome)
	local genomeCopy = newGenome(); -- the copy of an existing genome
	for c = 1, #genome.connections do
		genomeCopy.connections[c] = copyConnect(genome.connections[c]);
	end
	genomeCopy.network = genome.network;
	genomeCopy.fitness = genome.fitness;
	genomeCopy.numConnects = genome.numConnects;
	genomeCopy.numNodes = genome.numNodes;
	
	return genomeCopy;
end

function firstGenGenome()
	local genome = newGenome(); -- genome of the first generation
	for i = 1, Inputs do -- all input and output nodes get connected
		local connect = newConnect();
		connect.inp = i;
		connect.outp = MaxNodes + Outputs;
		connect.weight = math.random() * 8 - 4; -- the weights are random
		connect.innov = i;
		genome.connections[i] = connect;
	end
	mutate(genome);
	
	return genome;
end

function newSpecies()
	local species = {};
	species.genomes = {};
	species.maxFitness = 0.0;
	species.avgFitness = 0.0;
	
	return species
end

function newPopulation()
	local population = {};
	population.species = {};
	population.generation = 0;
	
	return population;
end

function newInnov()
	innovation = innovation + 1;
	
	return innovation;
end
	
function newMaxNode()
	maxnode = maxnode + 1;
	
	return maxnode;
end

function breed(species)
	local offspring = {};
	
	if math.random() < ChanceCrossover then -- if reproduction isn't asexual
		parent1 = math.random(1, #species.genomes);
		parent2 = math.random(1, #species.genomes);
		
		while parent1 == parent2 do
			parent2 = math.random(1, #species.genomes);
		end
		
		offspring = crossover(species.genomes[parent1], species.genomes[parent2]); -- the genes of both parents are mixed
	else -- if reproduction is asexual
		parent = species.genomes[math.random(1, #species.genomes)];
		offspring = copyGenome(parent); -- the offspring simply receives the genes of it's parent
	end
	
	mutate(offspring); -- the child is mutated, so it's not identical to it's parent(s)
	
	return offspring;
end

function crossover(genome1, genome2)
	local offspring = newGenome();
	if genome1.fitness > genome2.fitness then -- missmatched genes/connections of first parent are used
		innovNum2 = {};
		for i = 1, #genome2.connections do
			local connect = genome2.connections[i];
			innovNum2[connect.innov] = connect;
		end
		
		for i = 1, #genome1.connections do
			local connect1 = genome1.connections[i];
			local connect2 = innovNum2[connnect1];
			if connect2 ~= nil and math.random(1,2) == 2 then -- if genes match and second parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect2);
				--table.insert(offspring.connections, copyConnect(connect2));
			else -- if genes don't match or other parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);
				--table.insert(offspring.connections, copyConnect(connect1));
			end
		end
	elseif genome2.fitness > genome1.fitness then -- missmatched genes/connections of second parent are used
		innovNum1 = {};
		for i = 1, #genome1.connections do
			local connect = genome1.connections[i];
			innovNum1[connect.innov] = connect;
		end
		
		for i = 1, #genome2.connections do
			local connect2 = genome2.connections[i];
			local connect1 = innovNum1[connnect2];
			if connect1 ~= nil and math.random(1,2) == 1 then -- if genes match and first parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);
				--table.insert(offspring.connections, copyConnect(connect1));
			else -- if genes don't match or other parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect2);
				--table.insert(offspring.connections, copyConnect(connect2));
			end
		end
	else -- all genes/connections are used
		innovNum1 = {};
		for i = 1, #genome1.connections do
			local connect = genome1.connections[i];
			innovNum1[connect.innov] = connect;
		end
		
		innovNum2 = {};
		for i = 1, #genome2.connections do
			local connect = genome2.connections[i];
			innovNum2[connect.innov] = connect;
		end
		
		for i = 1, #genome2.connections do
			local connect2 = genome2.connections[i];
			local connect1 = innovNum1[connnect2];
			if connect1 ~= nil and math.random(1,2) == 1 then -- if genes match and first parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);
				--table.insert(offspring.connections, copyConnect(connect1));
			else -- if genes don't match or other parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect2);
				--table.insert(offspring.connections, copyConnect(connect2));
			end
		end
		
		for i = 1, #genome1.connections do
			local connect1 = genome1.connections[i];
			local connect2 = innovNum2[connnect1];
			if connect2 == nil then -- if genes don't match				
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);			
			end
		end
	end
	
	return offspring;
end

function mutateWeights(genome)
	for i = 1, #genome.connections do
		local connect = genome.connections[i];
		if math.random() > NewWeightChance then
			connect.weight = connect.weight + math.random()*WeightLrngRate;
		else
			connect.weight = math.random() * 8 - 4;
		end
	end
end

function mutateConnect(genome)
	local inpNode = genome.connections[math.random(1, #genome.connections)].inp;
	local outpNode = genome.connections[math.random(1, #genome.connections)].outp;
	
	while inpNode == outpNode do
		outpNode = genome.connections[math.random(1, #genome.connections)].outp;
	end
	
	local connect = newConnect();
	connect.inp = inpNode;
	connect.outp = outpNode;
	connect.weight =  math.random() * 8 - 4;
	
	if connectExists(genome.connections, connect) == true then
		return;
	end
	

	connect.innov = newInnov();
	genome.connections[#genome.connections + 1] = connect;
end

function mutateNode(genome)
	local connect = genome.connections[math.random(1, #genome.connections)];
	if connect.enabled == false then
		return;
	end
	
	newMaxNode();
	
	local connect1 = copyConnect(connect);
	connect1.outp = maxnode;
	connect1.weight = 1.0;
	connect1.innov = newInnov();
	
	local connect2 = copyConnect(connect);
	connect2.inp = maxnode; 
	connect2.innov = newInnov();	
	
	connect.enabled = false;
	
	genome.connections[#genome.connections + 1] = connect1;
	genome.connections[#genome.connections + 1] = connect2;
end

function mutateDisableConnect(genome)
	local enabledConnections = {};
	for c = 1, #genome.connections do
		if genome.connections[c].enabled == true then
			enabledConnections[#enabledConnections + 1] = genome.connections[c];
		end
	end
	
	if #enabledConnections == 0 then
		return;
	end
	
	local connect = enabledConnections[math.random(1, #enabledConnections)];
	connect.enabled = false;
end

function mutateEnableConnect(genome)
	local disabledConnections = {};
	for c = 1, #genome.connections do
		if genome.connections[c].enabled == false then
			disabledConnections[#disabledConnections + 1] = genome.connections[c];	
		end
	end
	
	if #disabledConnections == 0 then
		return;
	end
	
	local connect = disabledConnections[math.random(1, #disabledConnections)];
	connect.enabled = true;
end

function mutate(genome)
	if math.random() <= WeightMutChance then
		mutateWeights(genome);
	end
	
	if math.random() <= NewNodeChance  and maxnode < MaxNodes then
		mutateNode(genome);
	end
	
	if math.random() <= NewConnectChance then
		mutateConnect(genome);
	end
	
	if math.random() <= DisableChance then
		mutateDisableConnect(genome);
	end
	
	if math.random() <= EnableChance then
		mutateEnableConnect(genome);
	end
end

function getNetwork(genome)
	local network = {};
	network.nodes = {};
	local activeConnects = 0;
	local activeNodes = 0;
	
	for i = 1, Inputs do
		network.nodes[i] = newNode();
		activeNodes = activeNodes + 1; 
	end
	
	for o = 1, Outputs do
		network.nodes[MaxNodes + o] = newNode();
		activeNodes = activeNodes + 1; 
	end
		
	for c = 1, #genome.connections do
		local connect = genome.connections[c];
		if connect.enabled == true then
			activeConnects = activeConnects + 1;
			if network.nodes[connect.outp] == nil then
				network.nodes[connect.outp] = newNode();
				activeNodes = activeNodes + 1; 
			end
			if network.nodes[connect.inp] == nil then
				network.nodes[connect.inp] = newNode();
				activeNodes = activeNodes + 1; 
			end
			local node = network.nodes[connect.outp];
			node.ancestors[connect.inp] = connect.inp;
			node.rank = node.rank + 1;
			node.inps[#node.inps + 1] = connect;
		end
	end
	
	local updated = true;
	while updated == true do
		updated = false;
		for key,node in pairs(network.nodes) do
			if #node.inps > 0 then
				for c = 1, #node.inps do
					local connect = node.inps[c];
					local inpNode = network.nodes[connect.inp];
					if #inpNode.inps > 0 then
						for inpKey,_ in pairs(inpNode.ancestors) do
							if key ~= inpKey and node.ancestors[inpKey] == nil then
								node.ancestors[inpKey] = inpKey;
								node.rank = node.rank + 1;
								updated = true;
							end
						end
					end
				end
			end
		end
	end
	
	genome.numConnects = activeConnects;
	genome.numNodes = activeNodes;
	genome.network = network;
end
				
function calcOutputNet(network)
	local inputs = getInputs();
	for i = 1, Inputs do
		local node = network.nodes[i];
		if inputs[i] == nil then
			node.value = 0.0;
		else
			node.value = inputs[i];
		end
	end
	
	local outputNode = network.nodes[MaxNodes + Outputs];
	local maxRank = outputNode.rank;
	
	for r = 1, maxRank do
		for _,node in pairs(network.nodes) do
			if node.rank == r then
				local value = 0.0;
				for c = 1, #node.inps do
					local connect = node.inps[c];
					local inpNode = network.nodes[connect.inp];
					value = value + connect.weight*inpNode.value;
				end
				
				node.value = shiftedSigmoid(value);
			end
		end
	end
	
	return network.nodes[MaxNodes + Outputs].value;
end

function calcAvgFitness(species)
	local sum = 0;
	for g = 1, #species.genomes do
		local genome = species.genomes[g];
		sum = sum + genome.fitness;
	end
	
	species.avgFitness = sum / #species.genomes;
end

function calcTtlAvgFitness(population)
	local sum = 0;
	for s = 1, #population.species do
		local species = population.species[s];
		sum = sum + species.avgFitness;
	end
	
	return sum;
end

function removeWeakGenomes(population)
	for s = 1, #population.species do
		local species = population.species[s];
		local survivorCount = math.ceil(#species.genomes / 2);
		
		for i = 1, #species.genomes - 1 do
			for j = 1, #species.genomes - i do
				if species.genomes[j].fitness < species.genomes[j + 1].fitness then 
					local copyGen1 = copyGenome(species.genomes[j]);
					local copyGen2 = copyGenome(species.genomes[j + 1]);
					species.genomes[j] = copyGen2;
					species.genomes[j + 1] = copyGen1;
				end
			end
		end
		
		while #species.genomes > survivorCount do
			species.genomes[#species.genomes] = nil;
		end
	end
end

function removeWeakSpecies(population)
	local strongSpecies = {};
	for s = 1, #population.species do
		local species = population.species[s];
		calcAvgFitness(species);
	end
	
	local ttlAvgFitness = calcTtlAvgFitness(population);
	  
	for s = 1, #population.species do
		local species = population.species[s];
		if math.floor((species.avgFitness / ttlAvgFitness) * Population) >= 0 then
			strongSpecies[#strongSpecies + 1] = species;
		end 
	end
	
	population.species = strongSpecies;
end

function DisjointExcessCount(genome1, genome2)
	local disExcCount = 0;
	
	local innov1 = {};
	for c = 1, #genome1.connections do
		local connect = genome1.connections[c];
		innov1[connect.innov] = connect;
	end
	
	local innov2 = {};
	for c = 1, #genome2.connections do
		local connect = genome2.connections[c];
		innov2[connect.innov] = connect;
	end
	
	for c = 1, #genome1.connections do
		local connect = genome1.connections[c];
		if innov2[connect.innov] == nil then
			disExcCount = disExcCount + 1;
		end
	end
	
	for c = 1, #genome2.connections do
		local connect = genome2.connections[c];
		if innov1[connect.innov] == nil then
			disExcCount = disExcCount + 1;
		end
	end
	
	return disExcCount;
end

function getAvgWeightDiff(genome1, genome2)
	local avgWeightDiff = 0;
	local numSharedInnov = 0;
	
	local innov2 = {};
	for c = 1, #genome2.connections do
		local connect = genome2.connections[c];
		innov2[connect.innov] = connect;
	end
	
	for c = 1, #genome1.connections do
		local connect = genome1.connections[c];
		if innov2[connect.innov] ~= nil then
			numSharedInnov = numSharedInnov + 1;
			avgWeightDiff = avgWeightDiff + math.abs(innov2[connect.innov].weight - connect.weight);
		end
	end
	avgWeightDiff = avgWeightDiff / numSharedInnov;
	
	return avgWeightDiff;
end

function matchingSpecies(genome1, genome2)
	local n = math.max(#genome1.connections, #genome2.connections);
	local distance = (CoeffDisjointExcess * DisjointExcessCount(genome1, genome2) / n) + (CoeffWeightDiff * getAvgWeightDiff(genome1, genome2));
	if distance > DistanceTresh then
		return false;
	else
		return true;
	end
end
	

function insertIntoSpecies(genome, population)
	local speciesIdentified = false;
	
	if #population.species > 0 then
		for s = 1, #population.species do
			local species = population.species[s];
			if speciesIdentified == false and matchingSpecies(genome, species.genomes[1]) == true then
				species.genomes[#species.genomes + 1] = genome;
				speciesIdentified = true;
			end
		end
	end
	
	if speciesIdentified == false then
		local newSpecies = newSpecies();
		newSpecies.genomes[1] = genome;
		population.species[#population.species + 1] = newSpecies;
	end
end

function newGeneration(population)
	removeWeakSpecies(population);
	local ttlAvgFitness = calcTtlAvgFitness(population);
	removeWeakGenomes(population);
	
	local newGenomes = {};
	
	for s = 1, #population.species do
		local species = population.species[s];
		local offspringCount = math.floor((species.avgFitness / ttlAvgFitness) * Population);
		
		for o = 1, offspringCount do
			newGenomes[#newGenomes + 1] = breed(species);
		end 
	end
	
	while #newGenomes < Population do
		local species = population.species[math.random(1, #population.species)];
		newGenomes[#newGenomes + 1] = breed(species);
	end
	
	while #population.species > 0 do
		population.species[#population.species] = nil;
	end
	
	for g = 1, #newGenomes do
		local genome = newGenomes[g];			
		insertIntoSpecies(genome, population);
	end
	
	population.generation = population.generation + 1;
end

console.clear();
table = joypad.get(1);
table["Button"] = true; -- "Button" ist der einzige Knopf auf nem Atari 2600-Controller
joypad.set(table, 1);
emu.frameadvance(); -- Start auf Titelbildschirm drücken

local pop = newPopulation();
pop.generation = 1;

for g = 1, Population do
	insertIntoSpecies(firstGenGenome(), pop);
end

while true do
	for s = 1, #pop.species do
		local species = pop.species[s];
		local genomesSpecies = #species.genomes;
		for g = 1, #species.genomes do
			local fitness = 0;
			local genome = species.genomes[g];
			getNetwork(genome);
			local lostGame = false;
			for i = 1, 5 do
				table["Button"] = true;
				joypad.set(table, 1);
				emu.frameadvance();
				emu.frameadvance();
			
				local firstMove = true;
				while lostGame == false do
					local pointsRAMOld = memory.readbyte(0x53); -- Punkte
					local xPipeRAMOld = memory.readbyte(0x04); -- Position der R�hre
					
					local output = calcOutputNet(genome.network);
					if output > 0.0 or firstMove == true then
						table["Button"] = true;
						joypad.set(table, 1);
						firstMove = false;
					end
					gui.text(10,10,"Generation:" .. pop.generation);
					gui.text(10,30,"Species:" .. s);
					gui.text(10,50,"Genome:" .. g);
					gui.text(10,70,"Genomes in Species:" .. genomesSpecies);
					gui.text(10,90, "Active nodes in Genome:" .. genome.numNodes);
					gui.text(10,110, "Active connections in Genome:" .. genome.numConnects);
					gui.text(10,130, "Maximal rank:" .. genome.network.nodes[MaxNodes + Outputs].rank);
					emu.frameadvance();
					
					gui.text(10,10,"Generation:" .. pop.generation);
					gui.text(10,30,"Species:" .. s);
					gui.text(10,50,"Genome:" .. g);
					gui.text(10,70,"Genomes in Species:" .. genomesSpecies);
					gui.text(10,90, "Active nodes in Genome:" .. genome.numNodes);
					gui.text(10,110, "Active connections in Genome:" .. genome.numConnects);
					gui.text(10,130, "Maximal rank:" .. genome.network.nodes[MaxNodes + Outputs].rank);
					emu.frameadvance();
					
					local pointsRAMNew = memory.readbyte(0x53); -- Punkte
					local xPipeRAMNew = memory.readbyte(0x04); -- Position der R�hre
					
					if (pointsRAMNew < pointsRAMOld and pointsRAMOld ~= 153 and pointsRAMNew ~= 0) or (pointsRAMNew == pointsRAMOld and xPipeRAMNew > xPipeRAMOld) then
						if fitness > 5 then
							lostGame = true;
							genome.fitness = genome.fitness + fitness;
						end
						firstMove = true;
						fitness = 0;
					else 
						fitness = fitness + 1;
					end
				end
				lostGame = false;			
			end		
			genome.fitness = genome.fitness / 5;
		end
	end
	newGeneration(pop);
end
