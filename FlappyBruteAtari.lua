function inTable(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return key end
    end
    return false
end

console.clear()
table = joypad.get(1);
table["Button"] = true; -- "Button" ist der einzige Knopf auf nem Atari 2600-Controller
joypad.set(table, 1);
emu.frameadvance(); -- Start auf Titelbildschirm drücken

value = math.random(100);
frameCount = 0;

used = {};
i = 1;

while true do
	yRAM = memory.readbyte(0x0B); --y Position von 25 bis 77
	pointsRAM = memory.readbyte(0x53); -- Punkte
	pipeRAM = memory.readbyte(0x24); -- Höhe der Röhre	
		
	if frameCount % 286 == 0 and frameCount > 0 then
		if pointsRAM < 1 then	
			used[i] = value;
			print(used[i]);
			i = i + 1;
			while true do
				value = math.random(100);		
				if inTable(used, value) == false then
					break;
				end
			end
		end		
		frameCount = 0;
	end
	
	gui.text(10,70,"Value:" .. value);
	gui.text(10,10,"y-Position:" .. yRAM);
	gui.text(10,30,"Punkte:" .. pointsRAM);
	gui.text(10,50,"Pipe:" .. pipeRAM);
	if yRAM + value < pipeRAM then --  Wert ausprobiert
		table["Button"] = true;
		joypad.set(table, 1);
	end
	
	emu.frameadvance();
	frameCount = frameCount + 1;
	
	-- Text wird in jedem Frame neu gezeichnet, sonst blinkt er die ganze Zeit
	gui.text(10,70,"Value:" .. value);
	gui.text(10,10,"y-Position:" .. yRAM);
	gui.text(10,30,"Punkte:" .. pointsRAM);
	gui.text(10,50,"Pipe:" .. pipeRAM);
	
	emu.frameadvance();
	frameCount = frameCount + 1;
end
