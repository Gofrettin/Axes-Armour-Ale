(* Store each dungeon, its levels and related info *)

unit universe;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, globalutils;

(* individual dungeon / cave *)
type
  dungeonLayout = record
    (* unique identifier *)
    uniqueID: smallint;
    (* human-readable name of dungeon *)
    title: string;
    (* is this a cave / dungeon etc *)
    dungeonType: smallint;
    (* total number of floors *)
    totalDepth: byte;
    (* current floor the player is on *)
    currentDepth: byte;
    (* array of dungeon floor maps *)
    dlevel: array[1..10, 1..MAXROWS, 1..MAXCOLUMNS] of tile;
    (* stores which parts of each floor is discovered *)
    discoveredTiles: array[1..10, 1..MAXROWS, 1..MAXCOLUMNS] of boolean;
    (* stores whether each floor has been visited *)
    isVisited: array[1..10] of boolean;
  end;

var
  dungeonList: array of dungeonLayout;

procedure createNewDungeon;

implementation

procedure createNewDungeon;
var
  i: byte;
begin
  // hardcoded values for testing
  uniqueID := 3;
  title := 'Test dungeon';
  dungeonType := 2;
  totalDepth := 3;
  currentDepth := 1;
  (* set each floor to unvisited *)
  for i := 1 to 10 do
  begin
    isVisited[i] := False;
  end;

end;

end.
