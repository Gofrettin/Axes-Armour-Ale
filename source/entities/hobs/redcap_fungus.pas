(* Redcap infected by fungus *)

unit redcap_fungus;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, smell, universe, combat_resolver;

(* Create a Redcap Fungus *)
procedure createRedcapFungus(uniqueid, npcx, npcy: smallint);
(* Take a turn *)
procedure takeTurn(id: smallint);
(* Creature death *)
procedure death;
(* Decision tree for Neutral state *)
procedure decisionNeutral(id: smallint);
(* Decision tree for Hostile state *)
procedure decisionHostile(id: smallint);
(* Decision tree for Escape state *)
procedure decisionEscape(id: smallint);
(* Move in a random direction *)
procedure wander(id, spx, spy: smallint);
(* Chase enemy *)
procedure chaseTarget(id, spx, spy: smallint);
(* Check if player is next to NPC *)
function isNextToPlayer(spx, spy: smallint): boolean;
(* Run from player *)
procedure escapePlayer(id, spx, spy: smallint);
(* Combat *)
procedure combat(id: smallint);
(* Sniff out the player *)
procedure followScent(id: smallint);

implementation

uses
  entities, globalutils, ui, los, map;

procedure createRedcapFungus(uniqueid, npcx, npcy: smallint);
begin
  (* Add a redcap to the list of creatures *)
  entities.listLength := length(entities.entityList);
  SetLength(entities.entityList, entities.listLength + 1);
  with entities.entityList[entities.listLength] do
  begin
    npcID := uniqueid;
    race := 'Infected Hob';
    intName := 'HobFungus';
    article := True;
    description := 'a Hob covered in fungus';
    glyph := chr(1);
    glyphColour := 'green';
    maxHP := randomRange(5, 7) + universe.currentDepth;
    currentHP := maxHP;
    attack := randomRange(entityList[0].attack - 1, entityList[0].attack + 2);
    defence := randomRange(entityList[0].defence + 1, entityList[0].defence + 3);
    weaponDice := 0;
    weaponAdds := 0;
    xpReward := maxHP;
    visionRange := 3;
    (* Counts number of turns the NPC is in pursuit *)
    moveCount := 0;
    targetX := 0;
    targetY := 0;
    inView := False;
    blocks := False;
    faction := redcapFaction;
    state := stateHostile;
    discovered := False;
    weaponEquipped := False;
    armourEquipped := False;
    isDead := False;
    stsDrunk := False;
    stsPoison := False;
    stsBewild := False;
    tmrDrunk := 0;
    tmrPoison := 0;
    tmrBewild := 0;
    hasPath := False;
    destinationReached := False;
    entities.initPath(uniqueid);
    posX := npcx;
    posY := npcy;
  end;
  (* Occupy tile *)
  map.occupy(npcx, npcy);
end;

procedure takeTurn(id: smallint);
begin
  case entityList[id].state of
    stateNeutral: decisionNeutral(id);
    stateHostile: decisionHostile(id);
    stateEscape: decisionEscape(id);
  end;
end;

procedure death;
begin
  Inc(deathList[11]);
end;

procedure decisionNeutral(id: smallint);
var
  stopAndSmellFlowers: byte;
begin
  stopAndSmellFlowers := globalutils.randomRange(1, 2);
  if (stopAndSmellFlowers = 1) then
    { Either wander randomly }
    wander(id, entityList[id].posX, entityList[id].posY)
  else
    { or stay in place }
    entities.moveNPC(id, entityList[id].posX, entityList[id].posY);
end;

procedure decisionHostile(id: smallint);
begin
  {------------------------------- If NPC can see the player }
  if (los.inView(entityList[id].posX, entityList[id].posY, entityList[0].posX,
    entityList[0].posY, entityList[id].visionRange) = True) then
  begin
    {------------------------------- If next to the player }
    if (isNextToPlayer(entityList[id].posX, entityList[id].posY) = True) then
      {------------------------------- Attack the Player }
      combat(id)
    else
      {------------------------------- Chase the player }
      chaseTarget(id, entityList[id].posX, entityList[id].posY);
  end

  { If not injured and player not in sight, smell them out }
  else if (entityList[id].moveCount > 0) then
  begin
    (* Randomly display a message that you are being chased *)
    if (randomRange(1, 5) = 3) then
      ui.displayMessage('You hear painful moaning');
    followScent(id);
  end

  {------------------------------- If health is below 50%, escape }
  else if (entityList[id].currentHP < (entityList[id].maxHP div 2)) then
  begin
    entityList[id].state := stateEscape;
    escapePlayer(id, entityList[id].posX, entityList[id].posY);
  end

  else
    {------------------------------- Wander }
    wander(id, entityList[id].posX, entityList[id].posY);
end;

procedure decisionEscape(id: smallint);
var
  i, x: byte;
begin
  { Check if player is in sight }
  if (los.inView(entityList[id].posX, entityList[id].posY, entityList[0].posX,
    entityList[0].posY, entityList[id].visionRange) = True) then
    { If the player is in sight, run away }
    begin
    escapePlayer(id, entityList[id].posX, entityList[id].posY);
    (* Randomly decide if the infected hob says anything *)
    i := randomRange(1, 10);
    if (i = 2) then
      begin
           x := randomRange(1, 4);
           case x of
             1 : ui.displayMessage('The Hob screams "Noooo!"');
             2 : ui.displayMessage('The Hob mutters "M M.. Matangoooo!"');
             3 : ui.displayMessage('The Hob wails "It''sss tooo late...."');
             else
               ui.displayMessage('"The mushrooms! Don''t let them touch yoooooo!"');
           end;
      end;
    end

  { If the player is not in sight }
  else
  begin
    { Heal if health is below 50% }
    if (entityList[id].currentHP < (entityList[id].maxHP div 2)) then
      Inc(entityList[id].currentHP, 3)
    else
      { Reset state to Neutral and wander }
      wander(id, entityList[id].posX, entityList[id].posY);
  end;
end;

procedure wander(id, spx, spy: smallint);
var
  direction, attempts, testx, testy: smallint;
  i, x: byte;
begin
  { Set NPC state }
  entityList[id].state := stateNeutral;
  attempts := 0;
  testx := 0;
  testy := 0;
  direction := 0;
  repeat
    (* Reset values after each failed loop so they don't keep dec/incrementing *)
    testx := spx;
    testy := spy;
    direction := random(6);
    (* limit the number of attempts to move so the game doesn't hang if NPC is stuck *)
    Inc(attempts);
    if attempts > 10 then
    begin
      entities.moveNPC(id, spx, spy);
      exit;
    end;
    case direction of
      0: Dec(testy);
      1: Inc(testy);
      2: Dec(testx);
      3: Inc(testx);
      4: testx := spx;
      5: testy := spy;
    end
  until (map.canMove(testx, testy) = True) and (map.isOccupied(testx, testy) = False);
  entities.moveNPC(id, testx, testy);
  (* Randomly decide if the infected hob says anything *)
  if (entityList[id].inView = True) then
  begin
  i := randomRange(1, 10);
  if (i = 2) then
      begin
         x := randomRange(1, 4);
         case x of
           1 : ui.displayMessage('The Hob screams "Help me! It''s growing inside meee!"');
           2 : ui.displayMessage('The Hob yells "Aah, it''s taking over my mind!"');
           3 : ui.displayMessage('The Hob whimpers "Noooo! I''m changing...."');
           else
             ui.displayMessage('The Hob screams "The mushrooms! Don''t let them touch yoooooo!"');
           end;
      end;
  end;
end;

procedure chaseTarget(id, spx, spy: smallint);
var
  newX, newY, dx, dy: smallint;
  distance: double;
begin
  newX := 0;
  newY := 0;
  (* Get new coordinates to chase the player *)
  dx := entityList[0].posX - spx;
  dy := entityList[0].posY - spy;
  if (dx = 0) and (dy = 0) then
  begin
    newX := spx;
    newy := spy;
  end
  else
  begin
    distance := sqrt(dx ** 2 + dy ** 2);
    dx := round(dx / distance);
    dy := round(dy / distance);
    newX := spx + dx;
    newY := spy + dy;
  end;
  (* New coordinates set. Check if they are walkable *)
  if (map.canMove(newX, newY) = True) then
  begin
    (* Do they contain the player *)
    if (map.hasPlayer(newX, newY) = True) then
    begin
      (* Remain on original tile and attack *)
      entities.moveNPC(id, spx, spy);
      combat(id);
    end
    (* Else if tile does not contain player, check for another entity *)
    else if (map.isOccupied(newX, newY) = True) then
    begin
      ui.bufferMessage('The hob bumps into ' + getCreatureName(newX, newY));
      entities.moveNPC(id, spx, spy);
    end
    (* if map is unoccupied, move to that tile *)
    else if (map.isOccupied(newX, newY) = False) then
      entities.moveNPC(id, newX, newY);
  end
  else
    wander(id, spx, spy);
end;

function isNextToPlayer(spx, spy: smallint): boolean;
begin
  Result := False;
  if (map.hasPlayer(spx, spy - 1) = True) then { NORTH }
    Result := True;
  if (map.hasPlayer(spx + 1, spy - 1) = True) then { NORTH EAST }
    Result := True;
  if (map.hasPlayer(spx + 1, spy) = True) then { EAST }
    Result := True;
  if (map.hasPlayer(spx + 1, spy + 1) = True) then { SOUTH EAST }
    Result := True;
  if (map.hasPlayer(spx, spy + 1) = True) then { SOUTH }
    Result := True;
  if (map.hasPlayer(spx - 1, spy + 1) = True) then { SOUTH WEST }
    Result := True;
  if (map.hasPlayer(spx - 1, spy) = True) then { WEST }
    Result := True;
  if (map.hasPlayer(spx - 1, spy - 1) = True) then { NORTH WEST }
    Result := True;
end;

procedure escapePlayer(id, spx, spy: smallint);
var
  newX, newY, dx, dy: smallint;
  distance: single;
begin
  newX := 0;
  newY := 0;
  (* Get new coordinates to escape the player *)
  dx := entityList[0].posX - spx;
  dy := entityList[0].posY - spy;
  if (dx = 0) and (dy = 0) then
  begin
    newX := spx;
    newy := spy;
  end
  else
  begin
    distance := sqrt(dx ** 2 + dy ** 2);
    dx := round(dx / distance);
    dy := round(dy / distance);
    if (dx > 0) then
      dx := -1;
    if (dx < 0) then
      dx := 1;
    dy := round(dy / distance);
    if (dy > 0) then
      dy := -1;
    if (dy < 0) then
      dy := 1;
    newX := spx + dx;
    newY := spy + dy;
  end;
  if (map.canMove(newX, newY) = True) then
  begin
    if (map.hasPlayer(newX, newY) = True) then
    begin
      entities.moveNPC(id, spx, spy);
      combat(id);
    end
    else if (map.isOccupied(newX, newY) = False) then
      entities.moveNPC(id, newX, newY);
  end
  else
    wander(id, spx, spy);
end;

procedure combat(id: smallint);
var
  damageAmount, chance: smallint;
begin
  damageAmount := globalutils.randomRange(1, entities.entityList[id].attack) -
    entities.entityList[0].defence;
  if (damageAmount > 0) then
  begin
    entities.entityList[0].currentHP :=
      (entities.entityList[0].currentHP - damageAmount);
    if (entities.entityList[0].currentHP < 1) then
    begin
      killer := 'an ' + entityList[id].race;
      exit;
    end
    else
    begin
      if (damageAmount = 1) then
        ui.displayMessage('The infected Hob clutches you')
      else
        ui.displayMessage('The infected Hob claws you, dealing ' + IntToStr(damageAmount) + ' damage');
      (* Update health display to show damage *)
      ui.updateHealth;
    end;
  end
  else
  begin
    chance := randomRange(1, 4);
    if (chance = 1) then
      ui.displayMessage('The infected Hob lunges but misses')
    else if (chance = 2) then
      ui.displayMessage('The infected Hob flails at you');
    combat_resolver.spiteDMG(id);
  end;
end;

procedure followScent(id: smallint);
var
  smellDir: char;
begin
  Dec(entityList[id].moveCount);
  smellDir := scentDirection(entities.entityList[id].posY, entities.entityList[id].posX);

  case smellDir of
    'n':
    begin
      if (map.canMove(entities.entityList[id].posX,
        (entities.entityList[id].posY - 1)) and
        (map.isOccupied(entities.entityList[id].posX,
        (entities.entityList[id].posY - 1)) = False)) then
        entities.moveNPC(id, entities.entityList[id].posX,
          (entities.entityList[id].posY - 1));
    end;
    'e':
    begin
      if (map.canMove((entities.entityList[id].posX + 1),
        entities.entityList[id].posY) and (map.isOccupied(
        (entities.entityList[id].posX + 1), entities.entityList[id].posY) = False)) then
        entities.moveNPC(id, (entities.entityList[id].posX + 1),
          entities.entityList[id].posY);
    end;
    's':
    begin
      if (map.canMove(entities.entityList[id].posX,
        (entities.entityList[id].posY + 1)) and
        (map.isOccupied(entities.entityList[id].posX,
        (entities.entityList[id].posY + 1)) = False)) then
        entities.moveNPC(id, entities.entityList[id].posX,
          (entities.entityList[id].posY + 1));
    end;
    'w':
    begin
      if (map.canMove((entities.entityList[id].posX - 1),
        entities.entityList[id].posY) and (map.isOccupied(
        (entities.entityList[id].posX - 1), entities.entityList[id].posY) = False)) then


        entities.moveNPC(id, (entities.entityList[id].posX - 1),
          entities.entityList[id].posY);
    end
    else
      entities.moveNPC(id, entities.entityList[id].posX, entities.entityList[id].posY);
  end;
end;

end.
