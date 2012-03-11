unit KM_CommonClasses;
{$I KaM_Remake.inc}
interface
uses
  Classes, Math, SysUtils, KM_NetworkTypes, KM_Points;


type
  { Extended with custom Read/Write commands which accept various types without asking for their length}
  TKMemoryStream = class(TMemoryStream)
  public
    procedure Write(const Value: AnsiString); reintroduce; overload;
    {$IFDEF UNICODE}
    procedure Write(const Value: UnicodeString); reintroduce; overload;
    {$ENDIF}
    procedure Write(const Value:TKMPointDir ); reintroduce; overload;
    function Write(const Value:TKMDirection): Longint; reintroduce; overload;
    function Write(const Value:TKMPoint ): Longint; reintroduce; overload;
    function Write(const Value:TKMPointF): Longint; reintroduce; overload;
    function Write(const Value:single   ): Longint; reintroduce; overload;
    function Write(const Value:integer  ): Longint; reintroduce; overload;
    function Write(const Value:cardinal ): Longint; reintroduce; overload;
    function Write(const Value:byte     ): Longint; reintroduce; overload;
    function Write(const Value:boolean  ): Longint; reintroduce; overload;
    function Write(const Value:word     ): Longint; reintroduce; overload;
    function Write(const Value:shortint ): Longint; reintroduce; overload;
    procedure WriteAsText(const aText: string);

    procedure Read(out Value: AnsiString); reintroduce; overload;
    {$IFDEF UNICODE}
    procedure Read(out Value: UnicodeString); reintroduce; overload;
    {$ENDIF}
    procedure Read(out Value:TKMPointDir); reintroduce; overload;
    function Read(out Value:TKMDirection): Longint; reintroduce; overload;
    function Read(out Value:TKMPoint    ): Longint; reintroduce; overload;
    function Read(out Value:TKMPointF   ): Longint; reintroduce; overload;
    function Read(out Value:single      ): Longint; reintroduce; overload;
    function Read(out Value:integer     ): Longint; reintroduce; overload;
    function Read(out Value:cardinal    ): Longint; reintroduce; overload;
    function Read(out Value:byte        ): Longint; reintroduce; overload;
    function Read(out Value:boolean     ): Longint; reintroduce; overload;
    function Read(out Value:word        ): Longint; reintroduce; overload;
    function Read(out Value:shortint    ): Longint; reintroduce; overload;
    procedure ReadAssert(const Value: string);
    function ReadAsText: string;
  end;

  TStreamEvent = procedure (aData: TKMemoryStream) of object;


  //Stores information about a multiplayer game to be sent: host -> server -> queriers
  TMPGameInfo = class
  public
    GameState:TMPGameState;
    Players:string;
    Map:string;
    GameTime:TDateTime;
    function GetFormattedTime:string;
    procedure LoadFromText(aText:string);
    function GetAsText:string;
    function GetAsHTML:string;
  end;


  //List that clears up its items, used only in Units/Houses}
  TKMList = class(TList)
  public
    procedure Clear; override;
  end;

  //todo: Convert to 0..N-1 form
  TKMPointList = class
  private
    fCount: Integer;
    fList: array of TKMPoint;
    function GetPoint(aIndex: Integer): TKMPoint;
    procedure SetPoint(aIndex: Integer; const aValue: TKMPoint); //1..Count
  public

    property Count: Integer read fCount;
    property Items[aIndex: Integer]: TKMPoint read GetPoint write SetPoint; default;

    procedure Clear; virtual;
    procedure AddEntry(aLoc: TKMPoint);
    function  RemoveEntry(aLoc: TKMPoint): Integer; virtual;
    procedure Insert(ID: Integer; aLoc: TKMPoint);
    function  GetRandom(out Point: TKMPoint): Boolean;
    function  GetClosest(aLoc: TKMPoint; out Point: TKMPoint): Boolean;
    procedure Inverse;
    function  GetTopLeft(out TL: TKMPoint): Boolean;
    function  GetBottomRight(out RB: TKMPoint): Boolean;
    procedure Save(SaveStream: TKMemoryStream); virtual;
    procedure Load(LoadStream: TKMemoryStream); virtual;
  end;


  //todo: Convert to 0..N-1 form
  TKMPointTagList = class(TKMPointList)
  public
    Tag, Tag2: array of Cardinal; //1..Count
    procedure Clear; override;
    procedure AddEntry(aLoc: TKMPoint; aTag,aTag2: Cardinal); reintroduce;
    function RemoveEntry(aLoc: TKMPoint): Integer; override;
    procedure Save(SaveStream: TKMemoryStream); override;
    procedure Load(LoadStream: TKMemoryStream); override;
  end;


  TKMPointDirList = class //Used for finding fishing places, fighting positions, etc.
  private
    fItems: array of TKMPointDir; //0..Count-1
    fCount: Integer;
    function GetItem(aIndex: Integer): TKMPointDir;
  public
    constructor Load(LoadStream: TKMemoryStream);
    procedure Clear;
    procedure AddItem(aLoc: TKMPointDir);

    property Count: Integer read fCount;
    property Items[aIndex: Integer]: TKMPointDir read GetItem; default;

    function GetRandom(out Point: TKMPointDir):Boolean;
    procedure Save(SaveStream: TKMemoryStream);
  end;


  //Custom Exception that includes a TKMPoint
  ELocError = class(Exception)
    Loc: TKMPoint;
    constructor Create(const Msg: string; aLoc:TKMPoint);
  end;


implementation
uses KM_Utils;


{ ELocError }
constructor ELocError.Create(const Msg: string; aLoc:TKMPoint);
begin
  Inherited Create(Msg);
  Loc := aLoc;
end;


{ TMPGameInfo }
procedure TMPGameInfo.LoadFromText(aText:string);
var M:TKMemoryStream;
begin
  M := TKMemoryStream.Create;
  try
    M.WriteAsText(aText);
    M.Read(GameState, SizeOf(GameState));
    M.Read(Players);
    M.Read(Map);
    M.Read(GameTime, SizeOf(GameTime));
  finally
    M.Free;
  end;
end;


function TMPGameInfo.GetFormattedTime:string;
begin
  if GameTime >= 0 then
    Result := FormatDateTime('hh:nn:ss', GameTime)
  else
    Result := '';
end;


function TMPGameInfo.GetAsText:string;
var M:TKMemoryStream;
begin
  M := TKMemoryStream.Create;

  M.Write(GameState, SizeOf(GameState));
  M.Write(Players);
  M.Write(Map);
  M.Write(GameTime, SizeOf(GameTime));

  Result := M.ReadAsText;
  M.Free;
end;


function TMPGameInfo.GetAsHTML:string;
begin
  Result := '';
  Result := Result + Map;
  Result := Result +'<BR>'+ GetFormattedTime;
  Result := Result +'<BR>'+ Players;
end;


{ TKMList }
procedure TKMList.Clear;
var i:integer;
begin
  for i:=0 to Count-1 do begin
    TObject(Items[i]).Free;
    Items[i]:=nil;
  end;
  Inherited;
end;


{ TKMemoryStream }
procedure TKMemoryStream.Write(const Value: AnsiString);
var I: Word;
begin
  I := Length(Value);
  inherited Write(I, SizeOf(I));
  if I = 0 then Exit;
  inherited Write(Pointer(Value)^, I);
end;

{$IFDEF UNICODE}
procedure TKMemoryStream.Write(const Value: UnicodeString);
var I: Word;
begin
  I := Length(Value);
  inherited Write(I, SizeOf(I));
  if I = 0 then Exit;
  inherited Write(Pointer(Value)^, I * SizeOf(Char));
end;
{$ENDIF}

procedure TKMemoryStream.Write(const Value:TKMPointDir);
begin
  Write(Value.Loc);
  inherited Write(Value.Dir, SizeOf(Value.Dir));
end;

function TKMemoryStream.Write(const Value:TKMDirection): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:TKMPoint): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:TKMPointF): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:single): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:integer): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:cardinal): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:byte): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:boolean): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:word): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;
function TKMemoryStream.Write(const Value:shortint): Longint;
begin Result := inherited Write(Value, SizeOf(Value)); end;


procedure TKMemoryStream.WriteAsText(const aText:string);
begin
  Position := 0;
  Write(Pointer(aText)^, Length(aText) * SizeOf(Char));
  Position := 0;
end;


procedure TKMemoryStream.Read(out Value: AnsiString);
var I: Word;
begin
  Read(I, SizeOf(I));
  SetLength(Value, I);
  if I=0 then exit;
  Read(Pointer(Value)^, I);
end;

{$IFDEF UNICODE}
procedure TKMemoryStream.Read(out Value: UnicodeString);
var I: Word;
begin
  Read(I, SizeOf(I));
  SetLength(Value, I);
  if I=0 then exit;
  Read(Pointer(Value)^, I * SizeOf(Char));
end;
{$ENDIF}


procedure TKMemoryStream.Read(out Value:TKMPointDir);
begin
  Read(Value.Loc);
  Read(Value.Dir, SizeOf(Value.Dir));
end;

function TKMemoryStream.Read(out Value:TKMDirection): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:TKMPoint): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:TKMPointF): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:single): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:integer): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:cardinal): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:byte): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:boolean): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:word): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;
function TKMemoryStream.Read(out Value:shortint): Longint;
begin Result := Inherited Read(Value, SizeOf(Value)); end;


procedure TKMemoryStream.ReadAssert(const Value: string);
var S: string;
begin
  Read(s);
  Assert(s = Value, 'TKMemoryStream.Read <> Value: '+Value);
end;

function TKMemoryStream.ReadAsText: string;
begin
  SetString(Result, PChar(Memory), Size div SizeOf(Char));
end;


{ TKMPointList }
procedure TKMPointList.Load(LoadStream:TKMemoryStream);
var i:integer;
begin
  Inherited Create;
  LoadStream.Read(fCount);
  SetLength(fList,Count+32);
  for i:=1 to fCount do
    LoadStream.Read(fList[i]);
end;


procedure TKMPointList.Clear;
begin
  fCount := 0;
  setlength(fList, 0);
end;


procedure TKMPointList.AddEntry(aLoc:TKMPoint);
begin
  inc(fCount);
  if fCount>length(fList)-1 then setlength(fList, fCount+32);
  fList[fCount]:=aLoc;
end;


{Remove point from the list if is there. Return index of removed entry or -1 on failure}
function TKMPointList.RemoveEntry(aLoc:TKMPoint):Integer;
var i: integer;
begin
  Result:=-1;
  for i:=1 to fCount do
    if KMSamePoint(fList[i],aLoc) then
    begin
      dec(fCount);
      Result := i;
      Break;
    end;
  if Result <> -1 then
    for i:=Result to fCount do
      fList[i] := fList[i+1];
end;


{ Insert an entry and check if list is still walkable
  Walkable means that every point is next to neighbour points }
procedure TKMPointList.Insert(ID:integer; aLoc:TKMPoint);
var i:integer;
begin
  AddEntry(fList[fCount]);
  for i:=fCount downto ID+1 do //todo: Replace with System.Move
    fList[i]:=fList[i-1];
  fList[ID]:=aLoc;

  if ID = 1 then Assert(GetLength(fList[ID],fList[ID+1])<1.5); //Inject first
  if ID = fCount then Assert(GetLength(fList[ID-1],fList[ID])<1.5); //Inject last
end;


function TKMPointList.GetRandom(out Point: TKMPoint):Boolean;
begin
  if Count=0 then
    Result := False
  else begin
    Point := fList[KaMRandom(fCount)+1];
    Result := True;
  end;
end;


function TKMPointList.GetClosest(aLoc: TKMPoint; out Point: TKMPoint): Boolean;
var i:integer;
begin
  if Count=0 then
    Result := False
  else begin
    Point := fList[1];
    for i:=2 to fCount do
    if GetLength(fList[i], aLoc) < GetLength(Point, aLoc) then
      Point := fList[i];
    Result := True;
  end;
end;


function TKMPointList.GetPoint(aIndex: Integer): TKMPoint;
begin
  Result := fList[aIndex];
end;


procedure TKMPointList.SetPoint(aIndex: Integer; const aValue: TKMPoint);
begin
  fList[aIndex] := aValue;
end;


//Reverse the list
procedure TKMPointList.Inverse;
var i:integer;
begin
  for i:=1 to Count div 2 do
    KMSwapPoints(fList[i],fList[Count-i+1]); //Do +1 since i starts from 1
end;


function TKMPointList.GetTopLeft(out TL: TKMPoint): Boolean;
var i:integer;
begin
  Result := Count > 0;
  if Result then
  begin
    TL := fList[1]; //Something to start with
    for i:=2 to Count do begin
      if fList[i].X < TL.X then TL.X := fList[i].X;
      if fList[i].Y < TL.Y then TL.Y := fList[i].Y;
    end;
  end;
end;


function TKMPointList.GetBottomRight(out RB: TKMPoint): Boolean;
var i:integer;
begin
  Result := Count > 0;
  if Result then
  begin
    RB := fList[1]; //Something to start with
    for i:=2 to Count do begin
      if fList[i].X > RB.X then RB.X := fList[i].X;
      if fList[i].Y > RB.Y then RB.Y := fList[i].Y;
    end;
  end;
end;


procedure TKMPointList.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  SaveStream.Write(Count);
  for i:=1 to Count do
    SaveStream.Write(fList[i]);
end;


{ TKMPointTagList }
procedure TKMPointTagList.Load(LoadStream: TKMemoryStream);
var i:integer;
begin
  Inherited; //Reads Count

  SetLength(Tag, Count + 32); //Make space in lists to write data to, otherwise we get "Range Check Error"
  SetLength(Tag2, Count + 32);
  for i := 1 to Count do
  begin
    LoadStream.Read(Tag[i]);
    LoadStream.Read(Tag2[i]);
  end;
end;


procedure TKMPointTagList.Clear;
begin
  Inherited;
  SetLength(Tag, 0);
  SetLength(Tag2, 0);
end;


procedure TKMPointTagList.AddEntry(aLoc: TKMPoint; aTag,aTag2: Cardinal);
begin
  Inherited AddEntry(aLoc);
  if Count>length(Tag)-1 then setlength(Tag,Count+32); //Expand the list
  if Count>length(Tag2)-1 then setlength(Tag2,Count+32); //+32 is just a way to avoid further expansions
  Tag[Count]:=aTag;
  Tag2[Count]:=aTag2;
end;


function TKMPointTagList.RemoveEntry(aLoc: TKMPoint): Integer;
var I: Integer;
begin
  Result := Inherited RemoveEntry(aLoc);
  if Result <> -1 then
    for I := Result to Count do
    begin
      Tag[I] := Tag[I+1];
      Tag2[I] := Tag2[I+1];
    end;
end;


procedure TKMPointTagList.Save(SaveStream: TKMemoryStream);
var i:integer;
begin
  Inherited; //Writes Count

  for i:=1 to Count do
  begin
    SaveStream.Write(Tag[i]);
    SaveStream.Write(Tag2[i]);
  end;
end;


{ TKMPointList }
constructor TKMPointDirList.Load(LoadStream: TKMemoryStream);
var
  I: Integer;
begin
  Inherited Create;
  LoadStream.Read(fCount);
  SetLength(fItems, fCount);
  for I := 0 to fCount - 1 do
  begin
    LoadStream.Read(fItems[I].Loc);
    LoadStream.Read(fItems[I].Dir);
  end;
end;


procedure TKMPointDirList.Clear;
begin
  fCount := 0;
  SetLength(fItems, 0);
end;


procedure TKMPointDirList.AddItem(aLoc: TKMPointDir);
begin
  if fCount >= Length(fItems) then
    SetLength(fItems, fCount + 32);
  fItems[fCount] := aLoc;
  inc(fCount);
end;


function TKMPointDirList.GetItem(aIndex: Integer): TKMPointDir;
begin
  Assert(InRange(aIndex, 0, fCount - 1));
  Result := fItems[aIndex];
end;


function TKMPointDirList.GetRandom(out Point: TKMPointDir):Boolean;
begin
  Result := False;
  if fCount > 0 then begin
    Point := fItems[KaMRandom(fCount)];
    Result := True;
  end;
end;


procedure TKMPointDirList.Save(SaveStream: TKMemoryStream);
var
  I: Integer;
begin
  SaveStream.Write(fCount);
  for I := 0 to fCount - 1 do
  begin
    SaveStream.Write(fItems[I].Loc);
    SaveStream.Write(fItems[I].Dir);
  end;
end;


end.
