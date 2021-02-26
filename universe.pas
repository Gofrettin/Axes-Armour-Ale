(* Store each dungeon, its levels and related info *)

unit universe;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, globalutils;

type
  dungeonLayout = record
    uniqueID: smallint;
    title: string;
    dungeonType: smallint;
    totalDepth: byte;
    currentDepth: byte;
    dlevel: array[1, 1..MAXROWS, 1..MAXCOLUMNS] of tile;
  end;

implementation

end.

