--Parameters
Inputs = 3; -- the amount of inputs
Outputs = 1; -- the amount of outputs

Population = 50; -- the amount of networks/genomes
MaxNodes = 16000; -- the maximal amount of nodes

WeightMutChance = 0.8; -- the chance for the weights to be changed
NewWeightChance = 0.1; -- the chance for a weight to be completely new
WeightLrngRate = 0.01; -- the step size of the weight changes
NewConnectChance = 0.03; -- the chance for a new connection
NewNodeChance = 0.05; -- the chance for a new node
DisableChance = 0.05; -- the chance for an aktive connection to get disabled
EnableChance = 0.25; -- the chance for an inaktive connection to get enabled
ChanceCrossover = 0.75; -- the chance for breeding to not be asexual
CoeffDisjointExcess = 0.05;  -- coefficient used during distance calculation. The amount of disjoint and excess nodes is multiplied with it
CoeffWeightDiff = 1.0; -- coefficient used during distance calculation. The average weight difference between shared connections is multiplied with it
DistanceThresh = 0.1; -- the distance treshold. Distances above it mean that two genomes belong to separate species
SigmoidInHL = true; -- this determines whether the sigmoid function is only used for the output node or also for the hidden layer nodes
BreedersPercentage = 0.2; -- this sets the percentage of genomes, per species, that get to breed (Values should not exceed 1.0)
JumpThresh = 0.0; -- the threshold at which an output leads to a jump
WeightRange = 1; -- the (new) random connection weights range from -WeightRange/2 to WeightRange/2

--Global Variables (Do not change these!)
innovation = Inputs; -- innovation at start
maxnode = Inputs; -- max node, excluding the ouput node, at start
pipeHeight = 0; -- used to calculate the height difference between the bird and the pipe
nextPipeHeight = 0; -- used to calculate the height difference between the bird and the pipe

function getInputs()
	local inputs = {}; -- input array
	local distX = 0; -- the distance between the bird and the pipe
	local distY = 0; -- the height difference between the bird and the pipe
	
	local xPipeRAM = memory.readbyte(0x0045); -- Used to calculate the distance between the bird and the pipe. Values range from 0 to 255
	if xPipeRAM ~= nil then
		distX = 255 - xPipeRAM;
	else 
		distX = 255;
	end
	
	if pipeHeight == 0 or xPipeRAM < 160 then
		local pipeHeightMod = memory.readbyte(0x003B);
		if pipeHeightMod ~= nil then
			pipeHeight = 94 + pipeHeightMod * 16;
		else 
			pipeHeight = 0;
		end
		nextPipeHeight = pipeHeight;
	end
	
	if pipeHeight ~= nextPipeHeight and xPipeRAM >= 200 and xPipeRAM <= 210 then
		pipeHeight = nextPipeHeight;
	end
	
	local yBirdRAM = memory.readbyte(0x003F); -- the bird's height. Values range from 10 (highest) to 185 (lowest)
	distY = pipeHeight - yBirdRAM;
	
	inputs[1] = distX/255; -- the distance between the bird and the pipe (Due to the division by 255, the vaules range from 0 to 1)	
	inputs[2] = distY/185; -- the height difference between the bird and the pipe (Due to the division by 185, the vaules range from -1 to 1)	
	inputs[3] = 1; -- used as bias
	
	return inputs;
end

function sigmoid(x) -- the sigmoid function
    return 1 / (1 + math.exp(x));
end

function shiftedSigmoid(x) -- a shifted sigmoid function. Retruns values from -1 to 1
	return 2 * sigmoid(x) - 1;
end

function newNode() 
	local node = {}; -- a neuron/node
	node.inps = {}; -- the connections to input neurons
	node.value = 0.0; -- the value of the neuron
	node.rank = 0; -- used for output-calculation. Is the number of ancestors this node has, excluding itself
	node.ancestors = {}; -- used to calculate the rank. Stores the number of all the nodes this node inherits information from
	
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

function connectExists(connectList, connect) -- used to check if an connection already exists
	for i = 1, #connectList do -- goes through all connections in a list
		local connect2 = connectList[i];
		if connect2.inp == connect.inp and connect2.outp == connect.outp then -- if the current connection has the same input and output nodes as the one we're checking against, return true
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
	for c = 1, #genome.connections do -- all the connections in the genome must be copies of the original genome's connections
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
		connect.weight = math.random() * WeightRange - WeightRange * 0.5; -- the weights are random
		connect.innov = i;
		genome.connections[i] = connect;
	end
	mutate(genome); -- the new genoome goes through the mutation process
	
	return genome;
end

function newSpecies()
	local species = {}; -- a species
	species.genomes = {}; -- the genomes that are members of this species
	species.maxFitness = 0.0; -- the maximal fitness of the species. Can be used to calculate the staleness of a species, which we don't do
	species.avgFitness = 0.0; -- the average fitness of a species. Used to calculate the amount of offspring that a species is entitled to
	
	return species
end

function newPopulation()
	local population = {}; -- a population
	population.species = {}; -- the species in the population
	population.generation = 0; -- the population's generation. This gets incremented whenever a new population of genomes is created
	
	return population;
end

function newInnov()
	innovation = innovation + 1; -- the innovation number of the latest innovation
	
	return innovation;
end
	
function newMaxNode()
	maxnode = maxnode + 1; -- the number of the newest node
	
	return maxnode;
end

function breed(species)
	local offspring = {}; -- the offspring that is being bred
	
	if math.random() < ChanceCrossover and #species.genomes > 1 then -- if reproduction isn't asexual
		parent1 = math.random(1, #species.genomes); -- the first parent
		parent2 = math.random(1, #species.genomes); -- the second parent
		
		while parent1 == parent2 do -- if the parents are identical a new parent is chosen to replace the second parent
			parent2 = math.random(1, #species.genomes);
		end
		
		offspring = crossover(species.genomes[parent1], species.genomes[parent2]); -- the genes of both parents are mixed
	else -- if reproduction is asexual
		parent = species.genomes[math.random(1, #species.genomes)]; -- the only parent
		offspring = copyGenome(parent); -- the offspring simply receives the genes of it's parent
	end
	
	mutate(offspring); -- the child is mutated, so it's not identical to it's parent(s)
	
	return offspring;
end

function crossover(genome1, genome2)
	local offspring = newGenome(); -- the offspring that s being bred
	if genome1.fitness > genome2.fitness then -- missmatched genes/connections of first parent are used
		innovNum2 = {}; -- stores the second parent's genomes at the address of their innovation. THis is used to determine which connections are shared by both parents
		for i = 1, #genome2.connections do
			local connect = genome2.connections[i];
			innovNum2[connect.innov] = connect;
		end
		
		for i = 1, #genome1.connections do -- goes through all connections of the first parent and compares the innovation numbers with those of the second parent
			local connect1 = genome1.connections[i];
			local connect2 = innovNum2[connnect1];
			if connect2 ~= nil and math.random(1,2) == 2 then -- if innovation numbers match and second parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect2);
			else -- if innovation numbers don't match or other parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);
			end
		end
	elseif genome2.fitness > genome1.fitness then -- missmatched genes/connections of second parent are used
		innovNum1 = {}; -- stores the first parent's genomes at the address of their innovation. THis is used to determine which connections are shared by both parents
		for i = 1, #genome1.connections do
			local connect = genome1.connections[i];
			innovNum1[connect.innov] = connect;
		end
		
		for i = 1, #genome2.connections do -- goes through all connections of the second parent and compares the innovation numbers with those of the first parent
			local connect2 = genome2.connections[i];
			local connect1 = innovNum1[connnect2];
			if connect1 ~= nil and math.random(1,2) == 1 then -- if innovation numbers match and first parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);
			else -- if innovation numbers don't match or other parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect2);
			end
		end
	else -- all genes/connections are used
		innovNum1 = {}; -- stores the first parent's genomes at the address of their innovation. THis is used to determine which connections are shared by both parents
		for i = 1, #genome1.connections do
			local connect = genome1.connections[i];
			innovNum1[connect.innov] = connect;
		end
		
		innovNum2 = {}; -- stores the second parent's genomes at the address of their innovation. THis is used to determine which connections are shared by both parents
		for i = 1, #genome2.connections do
			local connect = genome2.connections[i];
			innovNum2[connect.innov] = connect;
		end
		
		for i = 1, #genome2.connections do -- goes through all connections of the second parent and compares the innovation numbers with those of the first parent
			local connect2 = genome2.connections[i];
			local connect1 = innovNum1[connnect2];
			if connect1 ~= nil and math.random(1,2) == 1 then -- if innovation numbers match and first parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);
			else -- if innovation numbers don't match or other parent wins
				offspring.connections[#offspring.connections + 1] = copyConnect(connect2);
			end
		end
		
		for i = 1, #genome1.connections do -- goes through all connections of the first parent and compares the innovation numbers with those of the second parent
			local connect1 = genome1.connections[i];
			local connect2 = innovNum2[connnect1];
			if connect2 == nil then -- if innovation numbers don't match				
				offspring.connections[#offspring.connections + 1] = copyConnect(connect1);			
			end
		end
	end
	
	return offspring;
end

function mutateWeights(genome) -- changes the weights of the genome's connections
	for i = 1, #genome.connections do
		local connect = genome.connections[i];
		if math.random() > NewWeightChance then -- if the isn't completely new
			if math.random(1,2) == 1 then
				connect.weight = connect.weight + math.random()*WeightLrngRate; -- weight change is positive
			else
				connect.weight = connect.weight - math.random()*WeightLrngRate; -- weight change is negative
			end 
		else -- if the weight is completely new
			connect.weight = math.random() * WeightRange - WeightRange * 0.5;
		end
	end
end

function mutateConnect(genome) -- adds a new connection to the genome
	local inpNode = genome.connections[math.random(1, #genome.connections)].inp; -- the input node of the connection
	local outpNode = genome.connections[math.random(1, #genome.connections)].outp; -- the output node of the connection
	
	while inpNode == outpNode do -- if both nodes are identical, a new output node is chosen
		outpNode = genome.connections[math.random(1, #genome.connections)].outp;
	end
	
	local connect = newConnect(); -- the new connection
	connect.inp = inpNode; 
	connect.outp = outpNode;
	connect.weight =  math.random() * WeightRange - WeightRange * 0.5; -- the weight is random
	
	if connectExists(genome.connections, connect) == true then -- if the connectin already exists in this genome, then it doesn't get added and we return to the caller
		return;
	end
	

	connect.innov = newInnov(); -- increments the innovation number and asigns the new number to our new connection
	genome.connections[#genome.connections + 1] = connect; -- stores the connection in the genome's list
end

function mutateNode(genome) -- adds a new node to the genome
	local connect = genome.connections[math.random(1, #genome.connections)]; -- chooses a random connection in which the node shall be placed
	if connect.enabled == false then -- f the connection is disabled, then no new node gets added and we return to the caller
		return;
	end
	
	newMaxNode(); -- the number of the newest node gets incremented
	
	local connect1 = copyConnect(connect); -- the new connection going to the new node
	connect1.outp = maxnode; -- the output of the new connection is our new node
	connect1.weight = 1.0; -- the connection must be 1, so the values sent to the ld connection's output stays the same
	connect1.innov = newInnov(); -- increments the innovation number and asigns the new number to our new connection
	
	local connect2 = copyConnect(connect); -- the new connection leaving the new node. It's weight is identical to the old connection's weight
	connect2.inp = maxnode; -- the input of the new connection is our new node
	connect2.innov = newInnov(); -- increments the innovation number and asigns the new number to our new connection	
	
	connect.enabled = false; -- disables the old connection
	
	genome.connections[#genome.connections + 1] = connect1; -- stores the connection in the genome's list
	genome.connections[#genome.connections + 1] = connect2; -- stores the connection in the genome's list
end

function mutateDisableConnect(genome) -- disables a connection
	local enabledConnections = {}; -- stores the enabled connections
	for c = 1, #genome.connections do -- goes through all connections and stores those that are enabled
		if genome.connections[c].enabled == true then
			enabledConnections[#enabledConnections + 1] = genome.connections[c];
		end
	end
	
	if #enabledConnections == 0 then -- if all connections are disabled, then return
		return;
	end
	
	local connect = enabledConnections[math.random(1, #enabledConnections)]; -- choose one of the enabled connections
	connect.enabled = false; -- disable the chosen connection
end

function mutateEnableConnect(genome) -- enables a connection
	local disabledConnections = {}; -- stores the disabled connections
	for c = 1, #genome.connections do -- goes through all connections and stores those that are disabled
		if genome.connections[c].enabled == false then
			disabledConnections[#disabledConnections + 1] = genome.connections[c];	
		end
	end
	
	if #disabledConnections == 0 then -- if all connections are enabled, then return
		return;
	end
	
	local connect = disabledConnections[math.random(1, #disabledConnections)]; -- choose one of the disabled connections
	connect.enabled = true; -- enable the chosen connection
end

function mutate(genome) -- the mutation process that new genomes go through
	if math.random() <= WeightMutChance then -- if requirements are met, weights are changed
		mutateWeights(genome);
	end
	
	if math.random() <= NewNodeChance  and maxnode < MaxNodes then -- if requirements are met, a new node gets added
		mutateNode(genome);
	end
	
	if math.random() <= NewConnectChance then -- if requirements are met, a new connection gets added
		mutateConnect(genome);
	end
	
	if math.random() <= DisableChance then -- if requirements are met, a connection gets disabled
		mutateDisableConnect(genome);
	end
	
	if math.random() <= EnableChance then -- if requirements are met, a connection gets enabled
		mutateEnableConnect(genome);
	end
end

function getNetwork(genome) -- builds the genome's network
	local network = {}; -- the network
	network.nodes = {}; -- the array that will contain the network's nodes
	local activeConnects = 0; -- the amount of connections that are enabled
	local activeNodes = 0; -- the amount of nodes that receive or send information. Input and output nodes are always counted, even if not connection leads from or to them
	
	for i = 1, Inputs do -- creates all the input nodes
		network.nodes[i] = newNode();
		activeNodes = activeNodes + 1; -- increases the amount of active nodes by one, per each created input node
	end
	
	for o = 1, Outputs do -- creates all the input nodes
		network.nodes[MaxNodes + o] = newNode();
		activeNodes = activeNodes + 1; -- increases the amount of active nodes by one, per each created input node
	end
		
	for c = 1, #genome.connections do -- goes through all the genome's connections
		local connect = genome.connections[c]; -- the current connection
		if connect.enabled == true then -- if the connection is enabled
			activeConnects = activeConnects + 1; -- increases the amount of active connections by one
			if network.nodes[connect.outp] == nil then -- if the connection's target node doesn't exist
				network.nodes[connect.outp] = newNode(); -- create the connection's target node
				activeNodes = activeNodes + 1; -- increases the amount of active nodes by one
			end
			if network.nodes[connect.inp] == nil then -- if the connection's start node doesn't exist
				network.nodes[connect.inp] = newNode(); -- create the connection's start node
				activeNodes = activeNodes + 1; -- increases the amount of active nodes by one
			end
			local node = network.nodes[connect.outp]; -- the connection's target node
			node.ancestors[connect.inp] = connect.inp; -- stores the number of the connection's start node in the target's ancestor list
			node.rank = node.rank + 1; -- increases the rank of the target by one (due to the extra ancestor)
			node.inps[#node.inps + 1] = connect; -- store the connection in the target node's list of connections that lead to it
		end
	end
	
	local updated = true; -- is used to determine whether a node's ancestor list/rank has changed
	while updated == true do -- as long as a node's ancestor list/rank has changed...
		updated = false; -- set the value of updated to false. It only gets set to true again if a change occurs
		for key,node in pairs(network.nodes) do -- goes through all nodes
			if #node.inps > 0 then 
				for c = 1, #node.inps do -- goes through all the connections the current node is a target of
					local connect = node.inps[c]; -- the current connection
					local inpNode = network.nodes[connect.inp]; -- the starting node of the current connection
					if #inpNode.inps > 0 then
						for inpKey,_ in pairs(inpNode.ancestors) do -- goes through all the ancestors of the starting node
							if key ~= inpKey and node.ancestors[inpKey] == nil then -- if an ancestor isn't the target node (could happen in a cycle) or in the target node's ancestor list
								node.ancestors[inpKey] = inpKey; -- add the ancestor to the target node's ancestor list
								node.rank = node.rank + 1; -- increase the rank of the target node
								updated = true; -- set updated to true, so the descendants of the target can update their own lists and ranks, in the next while iteration
							end
						end
					end
				end
			end
		end
	end
	
	genome.numConnects = activeConnects; -- set the genome's number of active connections
	genome.numNodes = activeNodes; -- set the genome's number of active nodes
	genome.network = network; -- set the genome's network to the network we built
end
				
function calcOutputNet(network)-- calculates the output of the network
	local inputs = getInputs();
	for i = 1, Inputs do -- gets the value for the input nodes directly from the game
		local node = network.nodes[i];
		if inputs[i] == nil then
			node.value = 0.0;
		else
			node.value = inputs[i];
		end
	end
	
	local outputNode = network.nodes[MaxNodes + Outputs]; -- the output node
	local maxRank = outputNode.rank; -- the maximal rank of the network. If a node has a higher rank than the output node, then there's no active connection leading from it to the output node. Hence, that node may be ignored
	
	for r = 1, maxRank do -- goes through all the ranks from 1 to the output node's rank
		for _,node in pairs(network.nodes) do -- goes through all the nodes
			if node.rank == r then -- if their rank is equal to the current rank, it is time to calculate their value
				local value = 0.0; -- the value
				for c = 1, #node.inps do -- goes through all the connections leading to the current node
					local connect = node.inps[c]; -- the current connection
					local inpNode = network.nodes[connect.inp]; -- the starting ndoe of the current connection
					value = value + connect.weight*inpNode.value; -- add the starting node's value times the connection's weight to the value of our current target node
				end
				
				if node.rank == maxRank or SigmoidInHL == true then -- if the node is the output node or we want the sigmoid function to be used in the hidden layers too
					node.value = shiftedSigmoid(value); -- set the node's value to the sigmoided value we calculated
				else
					node.value = value; -- set the node's value to the value we calculated
				end
			end
		end
	end
	
	return network.nodes[MaxNodes + Outputs].value; -- return the value of the output node
end

function calcAvgFitness(species) -- calculates the average fitness of a species
	local sum = 0; -- the sum of fitnesses
	for g = 1, #species.genomes do -- goes through all the genomes in a species
		local genome = species.genomes[g]; -- the current genome
		sum = sum + genome.fitness; -- adds the fitness to our sum
	end
	
	species.avgFitness = sum / #species.genomes; -- sets the species's average fitness to the sum divided by the number of genomes in the species
end

function calcTtlAvgFitness(population) -- calculates the total average fitness of our population
	local sum = 0; -- the sum of average fitnesses
	for s = 1, #population.species do -- goes through all the species
		local species = population.species[s]; -- the current species
		sum = sum + species.avgFitness; -- adds the current species's fitness to our sum
	end
	
	return sum; -- returns the total average fitness
end

function removeWeakGenomes(population) -- removes the weak genomes from a population (used for breeding purposes. We don't want weakling parents. ;))
	for s = 1, #population.species do -- goes through all the species
		local species = population.species[s]; -- the current species
		local survivorCount = math.ceil(#species.genomes * BreedersPercentage); -- calculates the amount of surviving genomes in this species
		
		for i = 1, #species.genomes - 1 do -- sorts the genomes, based on their fitness, using the bubble sort algorithmus
			for j = 1, #species.genomes - i do
				if species.genomes[j].fitness < species.genomes[j + 1].fitness then -- if a genome has a smaller fitness than the one that follows it, swap their positions
					local copyGen1 = copyGenome(species.genomes[j]);
					local copyGen2 = copyGenome(species.genomes[j + 1]);
					species.genomes[j] = copyGen2;
					species.genomes[j + 1] = copyGen1;
				end
			end
		end
		
		while #species.genomes > survivorCount do -- while the amount of genomes is greate than the amount of breeders/survivors
			species.genomes[#species.genomes] = nil; -- delete the last genome (Thanks to sorting the genomes, it has the worst fitness.)
		end
	end
end

function removeWeakSpecies(population) -- removes weak species (Those whose average fitness is too low to receive any offspring.)
	local strongSpecies = {}; -- those species that will survive get save in this array
	for s = 1, #population.species do -- calculates the average fitness for all species
		local species = population.species[s];
		calcAvgFitness(species);
	end
	
	local ttlAvgFitness = calcTtlAvgFitness(population); -- calculates the total average fitness
	  
	for s = 1, #population.species do -- goes through all the species
		local species = population.species[s]; -- the current species
		if math.floor((species.avgFitness / ttlAvgFitness) * Population) >= 0 then -- if the average fitness divided by the total average fitness and multiplied by the population size is greater or equal to one
			strongSpecies[#strongSpecies + 1] = species; -- the species receives at least one offspring, so it may survive
		end 
	end
	
	population.species = strongSpecies; -- set the population's species list to the list of strong/surviving species, so the weak species are no longer part of the population
end

function DisjointExcessCount(genome1, genome2) -- counts the number of disjoint or excess connections between two genomes
	local disExcCount = 0; -- the number of disjoint or excess connections
	
	local innov1 = {}; -- stores the innovation numbers of the first genome
	for c = 1, #genome1.connections do
		local connect = genome1.connections[c];
		innov1[connect.innov] = connect;
	end
	
	local innov2 = {}; -- stores the innovation numbers of the second genome
	for c = 1, #genome2.connections do
		local connect = genome2.connections[c];
		innov2[connect.innov] = connect;
	end
	
	for c = 1, #genome1.connections do -- compares the innovation numbers of the first genome with those of the second genome
		local connect = genome1.connections[c];
		if innov2[connect.innov] == nil then -- if an innovation number in the first genome can't be found in the second genome
			disExcCount = disExcCount + 1; -- increment the number of disjoint/excess genomes by one
		end
	end
	
	for c = 1, #genome2.connections do -- compares the innovation numbers of the second genome with those of the first genome
		local connect = genome2.connections[c];
		if innov1[connect.innov] == nil then -- if an innovation number in the second genome can't be found in the first genome
			disExcCount = disExcCount + 1; -- increment the number of disjoint/excess genomes by one
		end
	end
	
	return disExcCount; -- return the number of disjoint and excess connections
end

function getAvgWeightDiff(genome1, genome2) -- calculates the average wieght difference between two genomes
	local avgWeightDiff = 0; -- the average weight difference
	local numSharedInnov = 0; -- the number of shared connections
	
	local innov2 = {}; -- stores the innovation numbers of the second genome
	for c = 1, #genome2.connections do
		local connect = genome2.connections[c];
		innov2[connect.innov] = connect;
	end
	
	for c = 1, #genome1.connections do -- compares the innovation numbers of the first genome with those of the second genome
		local connect = genome1.connections[c];
		if innov2[connect.innov] ~= nil then -- if an innovation number in the first genome can also be found in the second genome
			numSharedInnov = numSharedInnov + 1; -- increase the amount of shared connections by one
			avgWeightDiff = avgWeightDiff + math.abs(innov2[connect.innov].weight - connect.weight); -- add the absolute weight difference of the two identical connections to the average weight difference
		end
	end
	avgWeightDiff = avgWeightDiff / numSharedInnov; -- divide the average weight difference by the amount of shared connections, so it actually is the shared weight difference and not just the sum of differences
	
	return avgWeightDiff; -- return the average weight difference
end

function matchingSpecies(genome1, genome2) -- determines whether two genomes belong to the same species
	local n = math.max(#genome1.connections, #genome2.connections); -- the maximum amount of connections in the genomes
	local distance = (CoeffDisjointExcess * DisjointExcessCount(genome1, genome2) / n) + (CoeffWeightDiff * getAvgWeightDiff(genome1, genome2)); -- the distance between both connections (Formula was taken from the paper.)
	if distance > DistanceThresh then -- if the distance is greater than our threshold, then the genomes aren't members of the same species
		return false;
	else -- else, both genomes are members of the same species
		return true;
	end
end
	

function insertIntoSpecies(genome, population) -- inserts a genome into the first species it belongs to
	local speciesIdentified = false; -- if the genome's secies was identified this value gets set to true, to avoid adding the same genome to more than one species
	
	if #population.species > 0 then -- if the population has at least one species
		for s = 1, #population.species do -- goes through all the species in the population
			local species = population.species[s]; -- the current species
			if speciesIdentified == false and matchingSpecies(genome, species.genomes[1]) == true then -- if the species of the genome hasn't already been identified and the genome's species matches the species of the current species's first genome 
				species.genomes[#species.genomes + 1] = genome; -- add the genome to the species
				speciesIdentified = true; -- state that the species has been identified
			end
		end
	end
	
	if speciesIdentified == false then -- if none of the species were a match (or no species exists)
		local newSpecies = newSpecies(); -- create a new species
		newSpecies.genomes[1] = genome; -- add the genome to the new species
		population.species[#population.species + 1] = newSpecies; -- add the species to the population's species list
	end
end

function newGeneration(population) -- create a new generation of genomes
	removeWeakSpecies(population); -- removes the weak species
	local ttlAvgFitness = calcTtlAvgFitness(population); -- re-calculates the total average fitness (it had already been calculated, before removing the weak species)
	removeWeakGenomes(population); -- removes the weak genomes of each species
	
	local newGenomes = {}; -- stores the new generation's genomes until their species can be identified
	
	for s = 1, #population.species do -- goes through all species
		local species = population.species[s]; -- the current species
		local offspringCount = math.floor((species.avgFitness / ttlAvgFitness) * Population) - 1; -- calculates the amount of offspring the species deserves, base on its average fitness
		
		if offspringCount > 0 then
			for o = 1, offspringCount do -- breed as many offspring as the species deserves and add them to our new genome list
				newGenomes[#newGenomes + 1] = breed(species);
			end
		end 
	end
	
	while #newGenomes < (Population - #population.species) do -- while the population number hasn't been matched (-the amount of species because the  best genome of each species gets saved)
		local species = population.species[math.random(1, #population.species)]; -- choose a random species
		newGenomes[#newGenomes + 1] = breed(species); -- breed an offspring for the species and add them to our new genome list
	end
	
	for s = 1, #population.species do -- goes through all the species
		local species = population.species[s]; -- the current species
		while #species.genomes > 1 do -- deletes genomes until only the best genome of the species remains
			species.genomes[#species.genomes] = nil;
		end
	end
	
	for g = 1, #newGenomes do -- for all the new genomes
		local genome = newGenomes[g]; -- the current genome	 		
		insertIntoSpecies(genome, population); -- nserts the genome into the species it first matches
	end
	
	population.generation = population.generation + 1; -- increments the population's generation number by one
end


table = joypad.get(1);
table["start"] = true; -- "Start" ist der Startknopf
joypad.set(1, table);
emu.frameadvance(); -- Start auf Titelbildschirm drücken

local pop = newPopulation(); -- creates a new population
pop.generation = 1; -- set the generation number to one

for g = 1, Population do -- create as many first gen genomes as the population's size allows and insert them into matching species
	insertIntoSpecies(firstGenGenome(), pop);
end

while true do -- plays the game
	local avgFitnessGen = 0; -- the average fitness of the current generation
	local highscoreGen = 0; -- the highscore of the current generation (points)
	local highscoreGenFit = 0.0; -- the highscore of the current generation (fitness)
	for s = 1, #pop.species do -- goes through all the species
		local species = pop.species[s]; -- the current species
		local genomesSpecies = #species.genomes; -- the amount of genomes of the current species
		for g = 1, #species.genomes do -- goes through all the genomes in the current species
			local fitness = 0; -- the fitness of the current genome
			local genome = species.genomes[g]; -- the current genome
			genome.fitness = 0; -- resets the genome's fitness, for genomes that transcend generations
			getNetwork(genome); -- creates the genome's network
			local lostGame = false; -- is used to determine whether the current genome lost a game
			for i = 1, 5 do -- play five times per genome
				table["start"] = true; -- starts the game again after a loss
				joypad.set(1, table);
				emu.frameadvance();
				emu.frameadvance();
				local framesGame = 0; -- the amount of frames of the current game (isn't entirely accurate but serves its purpose)
		
				while lostGame == false do -- while the genome hasn't lost
					local unitsRAMOld = memory.readbyte(0x0041); -- Punkte
					local tensRAMOld = memory.readbyte(0x0042); -- Punkte
					local hundredsRAMOld = memory.readbyte(0x0043); -- Punkte
					local pointsOld = hundredsRAMOld * 100 + tensRAMOld * 10 + unitsRAMOld;
					local xPipeRAMOld = memory.readbyte(0x0045); -- Position der R�hre
					local yBirdRAMOld = memory.readbyte(0x003F); -- the bird's height. Values range from 10 (highest) to 185 (lowest)
					
					if pointsOld > highscoreGen then
						highscoreGen = pointsOld;
					end
					
					local output = calcOutputNet(genome.network); -- calculates the output
					if output > JumpThresh or framesGame < 15 then -- if the output is greater than a threshold or the fitness is smaller than 15 (the first 15 moves have to be jumps or the game gets stuck in the starting screen)
						table["A"] = true; -- A leads to a jump
						joypad.set(1, table);
					end
					
					gui.text(10,10,"Generation:" .. pop.generation);
					gui.text(10,30,"Species:" .. s);
					gui.text(10,50,"Genome:" .. g);
					gui.text(10,70,"Genomes in Species:" .. genomesSpecies);
					gui.text(10,90, "Highscore:" .. highscoreGen);
					gui.text(10,110, "Pipe height:" .. pipeHeight);
					gui.text(10,130, "Bird height:" .. yBirdRAMOld);
					gui.text(10,170, "Iteration:" .. i);
					gui.text(10,150, "Dist pipe:" .. xPipeRAMOld);
					emu.frameadvance();
					
					gui.text(10,10,"Generation:" .. pop.generation);
					gui.text(10,30,"Species:" .. s);
					gui.text(10,50,"Genome:" .. g);
					gui.text(10,70,"Genomes in Species:" .. genomesSpecies);
					gui.text(10,90, "Highscore:" .. highscoreGen);
					gui.text(10,110, "Pipe height:" .. pipeHeight);
					gui.text(10,130, "Bird height:" .. yBirdRAMOld);
					gui.text(10,170, "Iteration:" .. i);
					gui.text(10,150, "Dist pipe:" .. xPipeRAMOld);
					emu.frameadvance();
					
					local unitsRAMNew = memory.readbyte(0x0041); -- Punkte
					local tensRAMNew = memory.readbyte(0x0042); -- Punkte
					local hundredsRAMNew = memory.readbyte(0x0043); -- Punkte
					local pointsNew = hundredsRAMNew * 100 + tensRAMNew * 10 + unitsRAMNew;
					local xPipeRAMNew = memory.readbyte(0x0045); -- Position der R�hre
					local yBirdRAMNew = memory.readbyte(0x003F);
					
					if pointsNew > highscoreGen then
						highscoreGen = pointsNew;
					end
					
					if pointsNew > pointsOld then -- if the bird passed a pipe store the height of the next pipe and reward the game by an extra 100 fitness points
						local pipeHeightMod = memory.readbyte(0x003B);
						nextPipeHeight = 94 + pipeHeightMod * 16;
						fitness = fitness + 100;
					end
					if ((pointsNew <= pointsOld and xPipeRAMNew < xPipeRAMOld) or (yBirdRAMOld >= 177 or yBirdRAMNew >= 177)) and framesGame > 10 then -- the current game was lost
						lostGame = true; -- set lostGAme to true, so we exit the while-loop and start the next game
						genome.fitness = genome.fitness + fitness; -- add the fitness of the current game to the genome's fitness
						fitness = 0; -- reset the fitness, so the next game starts at zero again
						pipeHeight = 0; -- reset the pipe height
					else
						framesGame = framesGame + 1; -- if the game wasn't lost, increase the current frames count by one
						if yBirdRAMNew > 10  then
							fitness = fitness + 1; -- if the game wasn't lost and the bird isn't outside of the screen, increase the current fitness by one
						end
					end			
				end
				lostGame = false; -- set lost game to false again, so the next loop doesn't terminate prematurely			
			end		
			genome.fitness = genome.fitness / 5; -- after the genome hast lost five games, divide the fitness by 5 to get the genome's average fitness per game
			if genome.fitness > highscoreGenFit then
				highscoreGenFit = genome.fitness;
			end
			avgFitnessGen = avgFitnessGen + genome.fitness; -- adds the current genome's fitness to the generation's average fitness
		end
	end
	avgFitnessGen = avgFitnessGen / Population; -- divides the fitness summ by the size of the population
	local file = io.open("results.txt", "a");
	file:write("Generation:" .. pop.generation);
	file:write("\nAverage Fitness:" .. avgFitnessGen);
	file:write("\nHighscore (Points):" .. highscoreGen);
	file:write("\nHighscore (Fitness):" .. highscoreGenFit);
	file:write("\n");
	file:close();
	newGeneration(pop); -- after all genomes of the current generation are done playing, create a new generation and start again
end