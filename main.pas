(* Axes, Armour & Ale - Roguelike for Linux and Windows.
   @author (Chris Hawkins)
*)

unit main;

{$mode objfpc}{$H+}
{$IfOpt D+}
{$Define DEBUG}
{$EndIf}

interface

uses
  Classes, Forms, ComCtrls, Graphics, SysUtils, universe, map, player,
  globalutils, Controls, LCLType, ui, items, player_inventory;

type

  { TGameWindow }

  TGameWindow = class(TForm)
    StatusBar1: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: integer);
    procedure FormPaint(Sender: TObject);
    (* New game setup *)
    procedure newGame;
    (* Continue previous saved game *)
    procedure continueGame;
    (* Confirm quit game *)
    procedure confirmQuit;
    (* Free memory *)
    procedure freeMemory;
  private

  public
  end;

var
  GameWindow: TGameWindow;
  (* Display is drawn on tempScreen before being copied to canvas *)
  tempScreen, inventoryScreen, RIPscreen: TBitmap;
  (* 0 = titlescreen, 1 = game running, 2 = inventory screen, 3 = Quit menu, 4 = Game Over *)
  gameState: byte;
  (* Screen to display *)
  currentScreen: TBitmap;

implementation

uses
  entities, fov;

{$R *.lfm}

{ TGameWindow }

procedure TGameWindow.FormCreate(Sender: TObject);
begin
  gameState := 0;
  tempScreen := TBitmap.Create;
  tempScreen.Height := 578;
  tempScreen.Width := 835;
  inventoryScreen := TBitmap.Create;
  inventoryScreen.Height := 578;
  inventoryScreen.Width := 835;
  RIPscreen := TBitmap.Create;
  RIPscreen.Height := 578;
  RIPscreen.Width := 835;
  currentScreen := tempScreen;
  Randomize;
  if (ParamCount = 2) then
  begin
    if (ParamStr(1) = '--seed') then
      RandSeed := StrToDWord(ParamStr(2))
    else
    begin
      (* Set random seed *)
      {$IFDEF Linux}
      writeln('Not a valid parameter');
      RandSeed := RandSeed shl 8;
      {$ENDIF}
      {$IFDEF Windows}
      RandSeed := ((RandSeed shl 8) or GetProcessID);
      {$ENDIF}
    end;
  end;
  StatusBar1.SimpleText := 'Version ' + globalutils.VERSION;
  (* Check for previous save file *)
  if FileExists(GetUserDir + globalutils.saveFile) then
    ui.titleScreen(1)
  else
    ui.titleScreen(0);
end;

procedure TGameWindow.FormDestroy(Sender: TObject);
begin
  (* Don't try to save game from title screen *)
  if (gameState = 1) then
  begin
    globalutils.saveGame;
    freeMemory;
  end;
  tempScreen.Free;
  inventoryScreen.Free;
  RIPscreen.Free;
  {$IFDEF Linux}
  WriteLn('Axes, Armour & Ale - (c) Chris Hawkins');
  {$ENDIF}
  Application.Terminate;
end;

procedure gameLoop;
var
  i: smallint;
begin
  (* Check for player death at start of game loop *)
  if (entityList[0].currentHP <= 0) then
  begin
    player.gameOver;
    Exit;
  end;
  (* move NPC's *)
  entities.NPCgameLoop;
  (* Redraw Field of View after entities move *)
  fov.fieldOfView(entityList[0].posX, entityList[0].posY, entityList[0].visionRange, 1);
  (* Draw all visible items *)
  for i := 1 to items.itemAmount do
    if (map.canSee(items.itemList[i].posX, items.itemList[i].posY) = True) then
    begin
      items.itemList[i].inView := True;
      items.redrawItems;
      (* Display a message if this is the first time seeing this item *)
      if (items.itemList[i].discovered = False) then
      begin
        ui.displayMessage('You see a ' + items.itemList[i].itemName);
        items.itemList[i].discovered := True;
      end;
    end
    else
    begin
      items.itemList[i].inView := False;
      map.drawTile(itemList[i].posX, itemList[i].posY, 0);
    end;
  (* Redraw NPC's *)
  entities.redrawNPC;
  (* Update health display to show damage *)
  ui.updateHealth;
  if (entityList[0].currentHP <= 0) then
    (* Clear Look / Info box *)
    ui.displayLook(1, 'none', '', 0, 0);
  (* Redraw Player *)
  drawToBuffer(map.mapToScreen(entities.entityList[0].posX),
    map.mapToScreen(entities.entityList[0].posY),
    entities.playerGlyph);
  (* Process status effects *)
  player.processStatus;
  (* Check for player death at end of game loop *)
  if (entityList[0].currentHP <= 0) then
  begin
    player.gameOver;
    Exit;
  end;
end;

procedure TGameWindow.FormKeyDown(Sender: TObject; var Key: word);
begin
  if (gameState = 1) then
  begin // beginning of game input
    case Key of
      VK_LEFT, VK_NUMPAD4, VK_H:
      begin
        player.movePlayer(2);
        gameLoop;
        Invalidate;
      end;
      VK_RIGHT, VK_NUMPAD6, VK_L:
      begin
        player.movePlayer(4);
        gameLoop;
        Invalidate;
      end;
      VK_UP, VK_NUMPAD8, VK_K:
      begin
        player.movePlayer(1);
        gameLoop;
        Invalidate;
      end;
      VK_DOWN, VK_NUMPAD2, VK_J:
      begin
        player.movePlayer(3);
        gameLoop;
        Invalidate;
      end;
      VK_NUMPAD9, VK_U:
      begin
        player.movePlayer(5);
        gameLoop;
        Invalidate;
      end;
      VK_NUMPAD3, VK_N:
      begin
        player.movePlayer(6);
        gameLoop;
        Invalidate;
      end;
      VK_NUMPAD1, VK_B:
      begin
        player.movePlayer(7);
        gameLoop;
        Invalidate;
      end;
      VK_NUMPAD7, VK_Y:
      begin
        player.movePlayer(8);
        gameLoop;
        Invalidate;
      end;
      VK_G, VK_OEM_COMMA: // Get item
      begin
        player.pickUp;
        gameLoop;
        Invalidate;
      end;
      VK_D: // Drop item
      begin
        currentScreen := inventoryScreen;
        gameState := 2;
        player_inventory.drop(10);
        Invalidate;
      end;
      VK_Q: // Quaff item
      begin
        currentScreen := inventoryScreen;
        gameState := 2;
        player_inventory.quaff(10);
        Invalidate;
      end;
      VK_W: // Wear / Wield item
      begin
        currentScreen := inventoryScreen;
        gameState := 2;
        player_inventory.wield(10);
        Invalidate;
      end;
      VK_I: // Show inventory
      begin
        player_inventory.showInventory;
        Invalidate;
      end;
      VK_ESCAPE: // Quit game
      begin
        gameState := 3;
        confirmQuit;
      end;
    end;
  end // end of game input
  else if (gameState = 0) then
  begin // beginning of Title menu
    case Key of
      VK_N: newGame;
      VK_L: continueGame;
      VK_Q: Close();
    end; // end of title menu screen
  end
  else if (gameState = 2) then
  begin // beginning of inventory menu
    case Key of
      VK_ESCAPE:  // Exit
      begin
        player_inventory.menu(0);
        Invalidate;
      end;
      VK_D:  // Drop
      begin
        player_inventory.menu(1);
        Invalidate;
      end;
      VK_Q:  // Quaff
      begin
        player_inventory.menu(12);
        Invalidate;
      end;
      VK_W:  // Wear / Wield
      begin
        player_inventory.menu(13);
        Invalidate;
      end;
      VK_0:
      begin
        player_inventory.menu(2);
        Invalidate;
      end;
      VK_1:
      begin
        player_inventory.menu(3);
        Invalidate;
      end;
      VK_2:
      begin
        player_inventory.menu(4);
        Invalidate;
      end;
      VK_3:
      begin
        player_inventory.menu(5);
        Invalidate;
      end;
      VK_4:
      begin
        player_inventory.menu(6);
        Invalidate;
      end;
      VK_5:
      begin
        player_inventory.menu(7);
        Invalidate;
      end;
      VK_6:
      begin
        player_inventory.menu(8);
        Invalidate;
      end;
      VK_7:
      begin
        player_inventory.menu(9);
        Invalidate;
      end;
      VK_8:
      begin
        player_inventory.menu(10);
        Invalidate;
      end;
      VK_9:
      begin
        player_inventory.menu(11);
        Invalidate;
      end;
    end;  // end of inventory menu
  end
  else if (gameState = 3) then // Quit menu
  begin
    case Key of
      VK_Q:
      begin
        globalutils.saveGame;
        gameState := 0;
        freeMemory;
        Close();
      end;
      VK_X:
      begin
        freeMemory;
        globalutils.saveGame;
        gameState := 0;
        ui.clearLog;
        ui.titleScreen(1);
        Invalidate;
      end;
      VK_ESCAPE:
      begin
        gameState := 1;
        ui.rewriteTopMessage;
        Invalidate;
      end;
    end;
  end
  else if (gameState = 4) then // Game Over menu
  begin
    case Key of
      VK_Q:
      begin
        gameState := 0;
        freeMemory;
        Close();
      end;
      VK_X:
      begin
        freeMemory;
        gameState := 0;
        ui.clearLog;
        ui.titleScreen(0);
        currentScreen := tempScreen;
        Invalidate;
      end;
    end;
  end;
end;

(* Capture mouse position for the Look command *)
procedure TGameWindow.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: integer);
begin
  if (X >= 1) and (X <= 686) and (Y >= 1) and (Y <= 400) then
  begin
    (* Check for entity *)
    if (map.isOccupied(map.screenToMap(x), map.screenToMap(y)) = True) then
    begin
      (* Add check if they are visible *)
      if (isCreatureVisible(screenToMap(x), screenToMap(y)) = True) then
      begin
        (* Send entity name, current HP and max HP to UI display *)
        ui.displayLook(1, getCreatureName(screenToMap(x), screenToMap(y)), '',
          getCreatureHP(screenToMap(x), screenToMap(y)),
          getCreatureMaxHP(screenToMap(x), screenToMap(y)));
        Invalidate;
      end;
    end
    (* Check for item *)
    else if (items.containsItem(map.screenToMap(x), map.screenToMap(y)) = True) then
    begin
      ui.displayLook(2, getItemName(map.screenToMap(x), map.screenToMap(y)),
        getItemDescription(map.screenToMap(x), map.screenToMap(y)), 0, 0);
      Invalidate;
    end
    else
    begin
      (* Clear UI display *)
      ui.displayLook(1, 'none', '', 0, 0);
      Invalidate;
    end;
  end;
end;

procedure TGameWindow.FormPaint(Sender: TObject);
begin
  Canvas.Draw(0, 0, currentScreen);
end;


procedure TGameWindow.newGame;
begin
  {$IfDef DEBUG}
  {$IfDef Linux}
  writeln('Debugging info...');
  writeln('Random seed = ' + IntToStr(RandSeed));
  {$EndIf}
  {$EndIf}
  gameState := 1;
  killer := 'empty';
  playerTurn := 0;
  map.mapType := 0;

  universe.createNewDungeon(map.mapType);


  map.setupMap;
  map.setupTiles;
  entities.setupEntities;
  items.setupItems;
  (* Clear the screen *)
  tempScreen.Canvas.Brush.Color := globalutils.BACKGROUNDCOLOUR;
  tempScreen.Canvas.FillRect(0, 0, tempScreen.Width, tempScreen.Height);
  (* Spawn game entities *)
  entities.spawnNPCs;
  (* Drop items *)
  items.initialiseItems;
  (* Draw sidepanel *)
  ui.drawSidepanel;
  (* Setup players starting equipment *)
  player.createEquipment;
  ui.displayMessage('Welcome message to be added here...');
  gameLoop;
  Canvas.Draw(0, 0, tempScreen);
end;

procedure TGameWindow.continueGame;
begin
  gameState := 1;
  globalutils.loadGame;
  killer := 'empty';
  (* Clear the screen *)
  tempScreen.Canvas.Brush.Color := globalutils.BACKGROUNDCOLOUR;
  tempScreen.Canvas.FillRect(0, 0, tempScreen.Width, tempScreen.Height);
  map.setupTiles;
  map.loadMap;
  (* Add entities to the screen *)
  entities.setupEntities;
  entities.redrawNPC;
  (* Add items to the screen *)
  items.setupItems;
  items.redrawItems;
  (* Draw sidepanel *)
  ui.drawSidepanel;
  (* Check for equipped items *)
  player_inventory.loadEquippedItems;
  (* Setup player vision *)
  fov.fieldOfView(entities.entityList[0].posX, entities.entityList[0].posY,
    entities.entityList[0].visionRange, 1);
  ui.displayMessage('Welcome message to be added here...');
  gameLoop;
  Canvas.Draw(0, 0, tempScreen);
end;

procedure TGameWindow.confirmQuit;
begin
  ui.exitPrompt;
  Invalidate;
end;

procedure TGameWindow.freeMemory;
begin
  (* Map tiles *)
  map.caveFloorHi.Free;
  map.caveFloorDef.Free;
  map.caveWallHi.Free;
  map.caveWallDef.Free;
  map.blueDungeonFloorDef.Free;
  map.blueDungeonFloorHi.Free;
  map.blueDungeonWallDef.Free;
  map.blueDungeonWallHi.Free;
  map.caveWall2Def.Free;
  map.caveWall2Hi.Free;
  map.caveWall3Def.Free;
  map.caveWall3Hi.Free;
  map.downStairs.Free;
  map.upStairs.Free;
  map.bmDungeon3Def.Free;
  map.bmDungeon3Hi.Free;
  map.bmDungeon5Def.Free;
  map.bmDungeon5Hi.Free;
  map.bmDungeon6Def.Free;
  map.bmDungeon6Hi.Free;
  map.bmDungeon7Def.Free;
  map.bmDungeon7Hi.Free;
  map.bmDungeon9Def.Free;
  map.bmDungeon9Hi.Free;
  map.bmDungeon10Def.Free;
  map.bmDungeon10Hi.Free;
  map.bmDungeon11Def.Free;
  map.bmDungeon11Hi.Free;
  map.bmDungeon12Def.Free;
  map.bmDungeon12Hi.Free;
  map.bmDungeon13Def.Free;
  map.bmDungeon13Hi.Free;
  map.bmDungeon14Def.Free;
  map.bmDungeon14Hi.Free;
  map.greyFloorHi.Free;
  map.greyFloorDef.Free;
  map.bmDungeonBLHi.Free;
  map.bmDungeonBLDef.Free;
  map.bmDungeonBRHi.Free;
  map.bmDungeonBRDef.Free;
  map.bmDungeonTLDef.Free;
  map.bmDungeonTLHi.Free;
  map.bmDungeonTRDef.Free;
  map.bmDungeonTRHi.Free;
  map.blankTile.Free;
  cave1Def.Free;
  cave1Hi.Free;
  cave4Def.Free;
  cave4Hi.Free;
  cave5Def.Free;
  cave5Hi.Free;
  cave7Def.Free;
  cave7Hi.Free;
  cave16Def.Free;
  cave16Hi.Free;
  cave17Def.Free;
  cave17Hi.Free;
  cave20Def.Free;
  cave20Hi.Free;
  cave21Def.Free;
  cave21Hi.Free;
  cave23Def.Free;
  cave23Hi.Free;
  cave28Def.Free;
  cave28Hi.Free;
  cave29Def.Free;
  cave29Hi.Free;
  cave31Def.Free;
  cave31Hi.Free;
  cave64Def.Free;
  cave64Hi.Free;
  cave65Def.Free;
  cave65Hi.Free;
  cave68Def.Free;
  cave68Hi.Free;
  cave69Def.Free;
  cave69Hi.Free;
  cave71Def.Free;
  cave71Hi.Free;
  cave80Def.Free;
  cave80Hi.Free;
  cave81Def.Free;
  cave81Hi.Free;
  cave84Def.Free;
  cave84Hi.Free;
  cave85Def.Free;
  cave85Hi.Free;
  cave87Def.Free;
  cave87Hi.Free;
  cave92Def.Free;
  cave92Hi.Free;
  cave93Def.Free;
  cave93Hi.Free;
  cave95Def.Free;
  cave95Hi.Free;
  cave112Def.Free;
  cave112Hi.Free;
  cave113Def.Free;
  cave113Hi.Free;
  cave116Def.Free;
  cave116Hi.Free;
  cave117Def.Free;
  cave117Hi.Free;
  cave119Def.Free;
  cave119Hi.Free;
  cave124Def.Free;
  cave124Hi.Free;
  cave125Def.Free;
  cave125Hi.Free;
  cave127Def.Free;
  cave127Hi.Free;
  cave193Def.Free;
  cave193Hi.Free;
  cave197Def.Free;
  cave197Hi.Free;
  cave199Def.Free;
  cave199Hi.Free;
  cave209Def.Free;
  cave209Hi.Free;
  cave213Def.Free;
  cave213Hi.Free;
  cave215Def.Free;
  cave215Hi.Free;
  cave221Def.Free;
  cave221Hi.Free;
  cave223Def.Free;
  cave223Hi.Free;
  cave241Def.Free;
  cave241Hi.Free;
  cave245Def.Free;
  cave245Hi.Free;
  cave247Def.Free;
  cave247Hi.Free;
  cave253Def.Free;
  cave253Hi.Free;
  cave255Def.Free;
  cave255Hi.Free;
  (* Item sprites *)
  items.aleTankard.Free;
  items.wineFlask.Free;
  items.crudeDagger.Free;
  items.leatherArmour1.Free;
  items.clothArmour.Free;
  items.woodenClub.Free;
  (* Entity sprites *)
  entities.playerGlyph.Free;
  entities.caveRatGlyph.Free;
  entities.hyenaGlyph.Free;
  entities.caveBearGlyph.Free;
  entities.barrelGlyph.Free;
  entities.greenFungusGlyph.Free;
end;

end.
