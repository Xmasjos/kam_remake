unit KM_Scripting;
{$I KaM_Remake.inc}
interface
uses
  Classes, Math, SysUtils, StrUtils,
  uPSCompiler, uPSRuntime,
  KM_CommonClasses, KM_Defaults, KM_ScriptingESA;

  //Dynamic scripts allow mapmakers to control the mission flow

  //In TSK, there are no enemies and you win when you build the tannery.
  //In TPR, you must defeat the enemies AND build the tannery.

type
  TKMScripting = class
  private
    fScriptCode: AnsiString;
    fByteCode: AnsiString;
    fExec: TPSExec;
    fErrorString: string; //Info about found mistakes

    fEvents: TKMScriptEvents;
    fStates: TKMScriptStates;
    fActions: TKMScriptActions;

    function ScriptOnUses(Sender: TPSPascalCompiler; const Name: AnsiString): Boolean;
    procedure CompileScript;
    procedure LinkRuntime;
  public
    constructor Create;
    destructor Destroy; override;

    property ErrorString: string read fErrorString;
    procedure LoadFromFile(aFileName: string);

    procedure ProcDefeated(aPlayer: TPlayerIndex);
    procedure ProcHouseBuilt(aHouseType: THouseType; aOwner: TPlayerIndex);

    procedure Save(SaveStream: TKMemoryStream);
    procedure Load(LoadStream: TKMemoryStream);

    procedure UpdateState;
  end;


var
  fScripting: TKMScripting;


implementation
uses KM_Log, KM_ResourceHouse;


{ TKMScripting }
constructor TKMScripting.Create;
begin
  inherited;
  fExec := TPSExec.Create;  // Create an instance of the executer.
  fEvents := TKMScriptEvents.Create;
  fStates := TKMScriptStates.Create;
  fActions := TKMScriptActions.Create;
end;


destructor TKMScripting.Destroy;
begin
  FreeAndNil(fEvents);
  FreeAndNil(fStates);
  FreeAndNil(fActions);
  FreeAndNil(fExec);
  inherited;
end;


procedure TKMScripting.LoadFromFile(aFileName: string);
var
  SL: TStringList;
begin
  fErrorString := '';

  if not FileExists(aFileName) then
  begin
    fLog.AddNoTime(aFileName + ' was not found. It is okay for mission to have no dynamic scripts.');
    Exit;
  end;

  //Read the file line by line and try to add valid events
  SL := TStringList.Create;
  try
    SL.LoadFromFile(aFileName);
    fScriptCode := SL.Text;
    {fScriptCode := 'var I: Integer; ' +
                   'begin ' +
                   '  if States.GameTime = 10 then ' +
                   '    I := 27; ' +
                   '  if States.GameTime = I then ' +
                   '    Actions.ShowMsg(0, I); ' +
                   'end.';}
    CompileScript;
  finally
    SL.Free;
  end;
end;


//The OnUses callback function is called for each "uses" in the script.
//It's always called with the parameter 'SYSTEM' at the top of the script.
//For example: uses ii1, ii2;
//This will call this function 3 times. First with 'SYSTEM' then 'II1' and then 'II2'
function TKMScripting.ScriptOnUses(Sender: TPSPascalCompiler; const Name: AnsiString): Boolean;
begin
  if Name = 'SYSTEM' then
  begin

    Sender.AddTypeS('THouseType', '(utSerf, utAxeman)');

    //Register classes and methods to the script engine.
    //After that they can be used from within the script.
    with Sender.AddClassN(nil, fEvents.ClassName) do
    begin
      RegisterMethod('function HouseBuilt(aPlayer: Integer; aHouseIndex: Integer): Byte');
      RegisterMethod('function PlayerDefeated(aPlayer: Integer): Boolean');
    end;

    with Sender.AddClassN(nil, fStates.ClassName) do
    begin
      RegisterMethod('function GameTime: Cardinal');
    end;

    with Sender.AddClassN(nil, fActions.ClassName) do
    begin
      RegisterMethod('procedure ShowMsg(aPlayer: Integer; aIndex: Word)');
    end;

    //Register objects
    AddImportedClassVariable(Sender, 'Events', fEvents.ClassName);
    AddImportedClassVariable(Sender, 'States', fStates.ClassName);
    AddImportedClassVariable(Sender, 'Actions', fActions.ClassName);

    Result := True;
  end else
    Result := False;
end;


procedure TKMScripting.CompileScript;
var
  I: Integer;
  Compiler: TPSPascalCompiler;
begin
  Compiler := TPSPascalCompiler.Create; // create an instance of the compiler.
  try
    Compiler.OnUses := ScriptOnUses; // assign the OnUses event.
    if not Compiler.Compile(fScriptCode) then  // Compile the Pascal script into bytecode.
    begin
      for I := 0 to Compiler.MsgCount - 1 do
        fErrorString := fErrorString + Compiler.Msg[I].MessageToString + '|';
      Exit;
    end;

    Compiler.GetOutput(fByteCode); // Save the output of the compiler in the string Data.
  finally
    Compiler.Free;
  end;

  LinkRuntime;
end;


//Link the ByteCode with used functions and load it into Executioner
procedure TKMScripting.LinkRuntime;
var
  ClassImp: TPSRuntimeClassImporter;
begin
  //Create an instance of the runtime class importer
  ClassImp := TPSRuntimeClassImporter.Create;

  //Register classes and their exposed methods to Runtime (must be uppercase)
  with ClassImp.Add(TKMScriptEvents) do
  begin
    RegisterMethod(@TKMScriptEvents.HouseBuilt, 'HOUSEBUILT');
    RegisterMethod(@TKMScriptEvents.PlayerDefeated, 'PLAYERDEFEATED');
  end;

  with ClassImp.Add(TKMScriptStates) do
  begin
    RegisterMethod(@TKMScriptStates.GameTime, 'GAMETIME');
  end;

  with ClassImp.Add(TKMScriptActions) do
  begin
    RegisterMethod(@TKMScriptActions.ShowMsg, 'SHOWMSG');
  end;

  //Append classes info to Exec
  RegisterClassLibraryRuntime(fExec, ClassImp);

  if not fExec.LoadData(fByteCode) then // Load the data from the Data string.
  begin
    { For some reason the script could not be loaded. This is usually the case when a
      library that has been used at compile time isn't registered at runtime. }
    fErrorString := fErrorString + 'Uknown error in loading bytecode to Exec|';
    Exit;
  end;

  //Link script objects with objects
  SetVariantToClass(fExec.GetVarNo(fExec.GetVar('EVENTS')), fEvents);
  SetVariantToClass(fExec.GetVarNo(fExec.GetVar('STATES')), fStates);
  SetVariantToClass(fExec.GetVarNo(fExec.GetVar('ACTIONS')), fActions);
end;


procedure TKMScripting.ProcDefeated(aPlayer: TPlayerIndex);
begin
  fEvents.Add(etDefeated, [aPlayer]);
end;


procedure TKMScripting.ProcHouseBuilt(aHouseType: THouseType; aOwner: TPlayerIndex);
begin
  //Store house by its KaM index to keep it consistent with DAT scripts
  fEvents.Add(etHouseBuilt, [aOwner, HouseTypeToIndex[aHouseType]]);
end;


procedure TKMScripting.Load(LoadStream: TKMemoryStream);
begin
  LoadStream.Read(fScriptCode);

  CompileScript;
end;


procedure TKMScripting.Save(SaveStream: TKMemoryStream);
begin
  SaveStream.Write(fScriptCode);
  Assert(fEvents.Count = 0, 'We''d expect Events to be saved after UpdateState');
end;


procedure TKMScripting.UpdateState;
begin
  fExec.RunScript;

  //Remove any events, we need to process them only once
  fEvents.Clear;
end;


end.