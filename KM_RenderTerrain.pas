unit KM_RenderTerrain;
{$I KaM_Remake.inc}
interface
uses
  dglOpenGL, SysUtils, KromUtils, Math,
  KM_Defaults, KM_FogOfWar, KM_Pics, KM_ResourceSprites, KM_Points, KM_Terrain;

type
  TUVRect = array [1 .. 4, 1 .. 2] of Single; // Texture UV coordinates

  //Render terrain without sprites
  TRenderTerrain = class
  private
    fRect: TKMRect;
    fFOW: TKMFogOfWar;
    fTextG: GLuint; //Shading gradient for lighting
    function GetTileUV(Index: Word; Rot: Byte): TUVRect;
    procedure DoTiles(AnimStep: Integer);
    procedure DoOverlays;
    procedure DoLighting;
    procedure DoWater(AnimStep: Integer);
    procedure DoShadows;
  public
    constructor Create;
    procedure Render(aRect: TKMRect; AnimStep: Integer; aFOW: TKMFogOfWar);
    procedure RenderTile(Index: Byte; pX,pY,Rot: Integer);
  end;


implementation
uses KM_Render, KM_RenderAux, KM_Resource;


constructor TRenderTerrain.Create;
var
  I: Integer;
  pData: array [0..255] of Cardinal;
begin
  inherited;

  //Generate gradient programmatically
  //KaM uses [0..255] gradients
  //We use slightly smoothed gradients [16..255] for Remake
  //cos it shows much more of terrain on screen and it looks too contrast
  for I := 0 to 255 do
    pData[I] := EnsureRange(Round(I * 1.0625 - 16), 0, 255) * 65793 or $FF000000;

  fTextG := TRender.GenTexture(256, 1, @pData[0], tf_RGBA8);
end;


function TRenderTerrain.GetTileUV(Index: Word; Rot: Byte): TUVRect;
var
  TexO: array [1 .. 4] of Byte; // order of UV coordinates, for rotations
  A: Byte;
begin
  TexO[1] := 1;
  TexO[2] := 2;
  TexO[3] := 3;
  TexO[4] := 4;

  // Rotate by 90 degrees: 4-1-2-3
  if Rot and 1 = 1 then
  begin
    A := TexO[4];
    TexO[4] := TexO[3];
    TexO[3] := TexO[2];
    TexO[2] := TexO[1];
    TexO[1] := A;
  end;

  //Rotate by 180 degrees: 3-4-1-2
  if Rot and 2 = 2 then
  begin
    SwapInt(TexO[1], TexO[3]);
    SwapInt(TexO[2], TexO[4]);
  end;

  with GFXData[rxTiles, Index+1] do
  begin
    Result[TexO[1], 1] := Tex.u1; Result[TexO[1], 2] := Tex.v1;
    Result[TexO[2], 1] := Tex.u1; Result[TexO[2], 2] := Tex.v2;
    Result[TexO[3], 1] := Tex.u2; Result[TexO[3], 2] := Tex.v2;
    Result[TexO[4], 1] := Tex.u2; Result[TexO[4], 2] := Tex.v1;
  end;
end;


procedure TRenderTerrain.DoTiles(AnimStep: Integer);
  procedure LandLight(A: Single);
  begin
    glColor4f(A / 1.5 + 0.5, A / 1.5 + 0.5, A / 1.5 + 0.5, Abs(A * 2)); // Balanced looks
    //glColor4f(a*2,a*2,a*2,Abs(a*2)); //Deeper shadows
  end;
var
  TexC: TUVRect;
  I,K: Integer;
begin
  //First we render base layer, then we do animated layers for Water/Swamps/Waterfalls
  //They all run at different speeds so we can't adjoin them in one layer

  with fTerrain do
  for I := fRect.Top to fRect.Bottom do
  for K := fRect.Left to fRect.Right do
  begin
    glBindTexture(GL_TEXTURE_2D, GFXData[rxTiles, Land[I,K].Terrain+1].Tex.ID);
    glBegin(GL_QUADS);
    TexC := GetTileUV(Land[I,K].Terrain, Land[I,K].Rotation);

    glColor4f(1,1,1,1);
    if RENDER_3D then begin
      glTexCoord2fv(@TexC[1]); glVertex3f(K-1,I-1,-Land[I,K].Height/CELL_HEIGHT_DIV);
      glTexCoord2fv(@TexC[2]); glVertex3f(K-1,I  ,-Land[I+1,K].Height/CELL_HEIGHT_DIV);
      glTexCoord2fv(@TexC[3]); glVertex3f(K  ,I  ,-Land[I+1,K+1].Height/CELL_HEIGHT_DIV);
      glTexCoord2fv(@TexC[4]); glVertex3f(K  ,I-1,-Land[I,K+1].Height/CELL_HEIGHT_DIV);
    end else begin

      glTexCoord2fv(@TexC[1]); glVertex3f(K-1,I-1-Land[I,K].Height/CELL_HEIGHT_DIV, -I);
      glTexCoord2fv(@TexC[2]); glVertex3f(K-1,I  -Land[I+1,K].Height/CELL_HEIGHT_DIV, -I);
      glTexCoord2fv(@TexC[3]); glVertex3f(K  ,I  -Land[I+1,K+1].Height/CELL_HEIGHT_DIV, -I);
      glTexCoord2fv(@TexC[4]); glVertex3f(K  ,I-1-Land[I,K+1].Height/CELL_HEIGHT_DIV, -I);

      {if KAM_WATER_DRAW and (iW=1) and TileIsWater(KMPoint(K,I)) then
      begin
        TexC := GetTileUV(32, 0);

        LandLight(Land[I  ,K  ].Light);
        glTexCoord2fv(@TexC[1]); glVertex3f(K-1,I-1-Land[I,K].Height/CELL_HEIGHT_DIV, -I);
        LandLight(Land[I+1,K  ].Light);
        glTexCoord2fv(@TexC[2]); glVertex3f(K-1,I  -Land[I+1,K].Height/CELL_HEIGHT_DIV, -I);
        LandLight(Land[I+1,K+1].Light);
        glTexCoord2fv(@TexC[3]); glVertex3f(K  ,I  -Land[I+1,K+1].Height/CELL_HEIGHT_DIV, -I);
        LandLight(Land[I  ,K+1].Light);
        glTexCoord2fv(@TexC[4]); glVertex3f(K  ,I-1-Land[I,K+1].Height/CELL_HEIGHT_DIV, -I);
      end;}
    end;
    glEnd;
  end;
end;


procedure TRenderTerrain.DoWater(AnimStep: Integer);
type TAnimLayer = (alWater, alFalls, alSwamp);
var
  AL: TAnimLayer;
  I,K: Integer;
  TexC: TUVRect;
  TexOffset: Word;
begin
  //First we render base layer, then we do animated layers for Water/Swamps/Waterfalls
  //They all run at different speeds so we can't adjoin them in one layer
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  //Each new layer inflicts 10% fps drop
  for AL := Low(TAnimLayer) to High(TAnimLayer) do
  begin
    case AL of
      alWater: TexOffset := 300 * (AnimStep mod 8 + 1);       // 300..2400
      alFalls: TexOffset := 300 * (AnimStep mod 5 + 1 + 8);   // 2700..3900
      alSwamp: TexOffset := 300 * ((AnimStep mod 24) div 8 + 1 + 8 + 5); // 4200..4800
    end;

    with fTerrain do
    for I := fRect.Top to fRect.Bottom do
    for K := fRect.Left to fRect.Right do
    if (fFOW.CheckTileRevelation(K,I,true) > FOG_OF_WAR_ACT) then //No animation in FOW
    begin

      if (TexOffset + Land[I,K].Terrain + 1 > High(GFXData[rxTiles]))
      or (GFXData[rxTiles, TexOffset + Land[I,K].Terrain + 1].Tex.ID = 0) then Continue;

      glBindTexture(GL_TEXTURE_2D, GFXData[rxTiles, TexOffset + Land[I,K].Terrain + 1].Tex.ID);
      TexC := GetTileUV(TexOffset + Land[I,K].Terrain, Land[I,K].Rotation);

      glBegin(GL_QUADS);
        glColor4f(1,1,1,1);
        if RENDER_3D then begin
          glTexCoord2fv(@TexC[1]); glVertex3f(K-1,I-1,-Land[I,K].Height/CELL_HEIGHT_DIV);
          glTexCoord2fv(@TexC[2]); glVertex3f(K-1,I  ,-Land[I+1,K].Height/CELL_HEIGHT_DIV);
          glTexCoord2fv(@TexC[3]); glVertex3f(K  ,I  ,-Land[I+1,K+1].Height/CELL_HEIGHT_DIV);
          glTexCoord2fv(@TexC[4]); glVertex3f(K  ,I-1,-Land[I,K+1].Height/CELL_HEIGHT_DIV);
        end else begin
          glTexCoord2fv(@TexC[1]); glVertex3f(K-1,I-1-Land[I,K].Height/CELL_HEIGHT_DIV, -I);
          glTexCoord2fv(@TexC[2]); glVertex3f(K-1,I  -Land[I+1,K].Height/CELL_HEIGHT_DIV, -I);
          glTexCoord2fv(@TexC[3]); glVertex3f(K  ,I  -Land[I+1,K+1].Height/CELL_HEIGHT_DIV, -I);
          glTexCoord2fv(@TexC[4]); glVertex3f(K  ,I-1-Land[I,K+1].Height/CELL_HEIGHT_DIV, -I);
        end;
      glEnd;
    end;
  end;
end;


procedure TRenderTerrain.DoOverlays;
//   1      //Select road tile and rotation
//  8*2     //depending on surrounding tiles
//   4      //Bitfield
const
  RoadsConnectivity: array [0..15, 1..2] of Byte = (
    (248,0), (248,0), (248,1), (250,3),
    (248,0), (248,0), (250,0), (252,0),
    (248,1), (250,2), (248,1), (252,3),
    (250,1), (252,2), (252,1), (254,0));
var
  I, K: Integer;
  Road, ID, Rot: Byte;
begin
  glColor4f(1, 1, 1, 1);

  for I := fRect.Top to fRect.Bottom do
  for K := fRect.Left to fRect.Right do
  case fTerrain.Land[I, K].TileOverlay of
    to_Dig1:  RenderTile(249, K, I, 0);
    to_Dig2:  RenderTile(251, K, I, 0);
    to_Dig3:  RenderTile(253, K, I, 0);
    to_Dig4:  RenderTile(255, K, I, 0);
    to_Wall:  fRenderAux.Quad(K, I, $800000FF);
    to_Road:  begin
                Road := 0;
                if (I - 1 >= 1) then
                  Road := Road + byte(fTerrain.Land[I - 1, K].TileOverlay = to_Road) shl 0;
                if (K + 1 <= fTerrain.MapX - 1) then
                  Road := Road + byte(fTerrain.Land[I, K + 1].TileOverlay = to_Road) shl 1;
                if (I + 1 <= fTerrain.MapY - 1) then
                  Road := Road + byte(fTerrain.Land[I + 1, K].TileOverlay = to_Road) shl 2;
                if (K - 1 >= 1) then
                  Road := Road + byte(fTerrain.Land[I, K - 1].TileOverlay = to_Road) shl 3;
                ID := RoadsConnectivity[Road, 1];
                Rot := RoadsConnectivity[Road, 2];
                RenderTile(ID, K, I, Rot);
              end;
   end;
end;


procedure TRenderTerrain.DoLighting;
var
  I: Integer;
  K: Integer;
begin
  glColor4f(1, 1, 1, 1);
  //Render highlights
  glBlendFunc(GL_DST_COLOR, GL_ONE);
  glBindTexture(GL_TEXTURE_2D, fTextG);
  glBegin(GL_QUADS);
    with fTerrain do
    if RENDER_3D then
      for I := fRect.Top to fRect.Bottom do
      for K := fRect.Left to fRect.Right do
      begin
        glTexCoord1f(Land[  I,   K].Light); glVertex3f(K-1, I-1, -Land[  I,   K].Height / CELL_HEIGHT_DIV);
        glTexCoord1f(Land[I+1,   K].Light); glVertex3f(K-1,   I, -Land[I+1,   K].Height / CELL_HEIGHT_DIV);
        glTexCoord1f(Land[I+1, K+1].Light); glVertex3f(  K,   I, -Land[I+1, K+1].Height / CELL_HEIGHT_DIV);
        glTexCoord1f(Land[  I, K+1].Light); glVertex3f(  K, I-1, -Land[  I, K+1].Height / CELL_HEIGHT_DIV);
      end
    else
      for I := fRect.Top to fRect.Bottom do
      for K := fRect.Left to fRect.Right do
      begin
        glTexCoord1f(Land[  I,   K].Light); glVertex3f(K-1, I-1 - Land[  I,   K].Height / CELL_HEIGHT_DIV, -I);
        glTexCoord1f(Land[I+1,   K].Light); glVertex3f(K-1,   I - Land[I+1,   K].Height / CELL_HEIGHT_DIV, -I);
        glTexCoord1f(Land[I+1, K+1].Light); glVertex3f(  K,   I - Land[I+1, K+1].Height / CELL_HEIGHT_DIV, -I);
        glTexCoord1f(Land[  I, K+1].Light); glVertex3f(  K, I-1 - Land[  I, K+1].Height / CELL_HEIGHT_DIV, -I);
      end;
  glEnd;
end;


//Render shadows and FOW at once
procedure TRenderTerrain.DoShadows;
var
  I,K: Integer;
begin
  glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_COLOR);
  glBindTexture(GL_TEXTURE_2D, fTextG);
  glBegin(GL_QUADS);
    with fTerrain do
    if RENDER_3D then
      for I := fRect.Top to fRect.Bottom do
      for K := fRect.Left to fRect.Right do
      begin
        glTexCoord1f(kromutils.max(0, -Land[I, K].Light, 1 - fFOW.CheckVerticeRevelation(K - 1, I - 1, true) / 255));
        glVertex3f(K - 1, I - 1, -Land[I, K].Height / CELL_HEIGHT_DIV);
        glTexCoord1f(kromutils.max(0, -Land[I + 1, K].Light, 1 - fFOW.CheckVerticeRevelation(K - 1, I, true) / 255));
        glVertex3f(K - 1, I, -Land[I + 1, K].Height / CELL_HEIGHT_DIV);
        glTexCoord1f(kromutils.max(0, -Land[I + 1, K + 1].Light, 1 - fFOW.CheckVerticeRevelation(K, I, true) / 255));
        glVertex3f(K, I, -Land[I + 1, K + 1].Height / CELL_HEIGHT_DIV);
        glTexCoord1f(kromutils.max(0, -Land[I, K + 1].Light, 1 - fFOW.CheckVerticeRevelation(K, I - 1, true) / 255));
        glVertex3f(K, I - 1, -Land[I, K + 1].Height / CELL_HEIGHT_DIV);
      end
    else
      for I := fRect.Top to fRect.Bottom do
      for K := fRect.Left to fRect.Right do
      begin
        glTexCoord1f(max(-Land[I, K].Light, 1 - fFOW.CheckVerticeRevelation(K - 1, I - 1, true) / 255));
        glVertex3f(K - 1, I - 1 - Land[I, K].Height / CELL_HEIGHT_DIV, -I);
        glTexCoord1f(max(-Land[I + 1, K].Light, 1 - fFOW.CheckVerticeRevelation(K - 1, I, true) / 255));
        glVertex3f(K - 1, I - Land[I + 1, K].Height / CELL_HEIGHT_DIV, -I);
        glTexCoord1f(max(-Land[I + 1, K + 1].Light, 1 - fFOW.CheckVerticeRevelation(K, I, true) / 255));
        glVertex3f(K, I - Land[I + 1, K + 1].Height / CELL_HEIGHT_DIV, -I);
        glTexCoord1f(max(-Land[I, K + 1].Light, 1 - fFOW.CheckVerticeRevelation(K, I - 1, true) / 255));
        glVertex3f(K, I - 1 - Land[I, K + 1].Height / CELL_HEIGHT_DIV, -I);
      end;
  glEnd;
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glBindTexture(GL_TEXTURE_2D, 0);
end;


procedure TRenderTerrain.Render(aRect: TKMRect; AnimStep: Integer; aFOW: TKMFogOfWar);
var
  I,K: Integer;
begin
  fRect := aRect;
  fFOW := aFOW;

  glPushAttrib(GL_DEPTH_BUFFER_BIT);

    //With depth test we can render all terrain tiles and then apply light/shadow without worrying about
    //foothills shadows going over mountain tops. Each tile strip is rendered an next Z plane.
    //Means that Z-test on gpu will take care of clipping the foothill shadows
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);

    DoTiles(AnimStep);

    DoOverlays;

    //DoWater(AnimStep); //Old

    DoLighting;

    DoWater(AnimStep); //New

    DoShadows;

    if SHOW_WALK_CONNECT then
    begin
      glPushAttrib(GL_DEPTH_BUFFER_BIT);
        glDisable(GL_DEPTH_TEST);

        for I := aRect.Top to aRect.Bottom do
        for K := aRect.Left to aRect.Right do
          fRenderAux.Text(K, I, IntToStr(fTerrain.Land[I,K].WalkConnect[wcWalk]), $FFFFFFFF);

      glPopAttrib;
    end;

  glPopAttrib;
end;


{Render one terrian cell}
procedure TRenderTerrain.RenderTile(Index: Byte; pX,pY,Rot: Integer);
var
  K, I: Integer;
  TexC: TUVRect; // Texture UV coordinates
begin
  if not fTerrain.TileInMapCoords(pX,pY) then Exit;

  K := pX;
  I := pY;
  glColor4f(1, 1, 1, 1);

  glBindTexture(GL_TEXTURE_2D, GFXData[rxTiles, Index + 1].Tex.ID);
  TexC := GetTileUV(Index, Rot);

  glBegin(GL_QUADS);
    with fTerrain do
    if RENDER_3D then
    begin
      glTexCoord2fv(@TexC[1]); glVertex3f(k-1,i-1,-Land[i,k].Height/CELL_HEIGHT_DIV);
      glTexCoord2fv(@TexC[2]); glVertex3f(k-1,i  ,-Land[i+1,k].Height/CELL_HEIGHT_DIV);
      glTexCoord2fv(@TexC[3]); glVertex3f(k  ,i  ,-Land[i+1,k+1].Height/CELL_HEIGHT_DIV);
      glTexCoord2fv(@TexC[4]); glVertex3f(k  ,i-1,-Land[i,k+1].Height/CELL_HEIGHT_DIV);
    end
    else
    begin
      glTexCoord2fv(@TexC[1]); glVertex3f(k-1,i-1-Land[i,k].Height/CELL_HEIGHT_DIV, -i);
      glTexCoord2fv(@TexC[2]); glVertex3f(k-1,i  -Land[i+1,k].Height/CELL_HEIGHT_DIV, -i);
      glTexCoord2fv(@TexC[3]); glVertex3f(k  ,i  -Land[i+1,k+1].Height/CELL_HEIGHT_DIV, -i);
      glTexCoord2fv(@TexC[4]); glVertex3f(k  ,i-1-Land[i,k+1].Height/CELL_HEIGHT_DIV, -i);
    end;
  glEnd;
  glBindTexture(GL_TEXTURE_2D, 0);
end;


end.