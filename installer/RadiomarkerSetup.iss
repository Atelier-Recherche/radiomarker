; Radiomarker - installeur Windows (Inno Setup 6)
; Compilation : ouvrir ce fichier dans Inno Setup Compiler puis Build > Compile.
; Sortie : ..\dist\RadiomarkerSetup.exe (voir OutputDir ci-dessous).

#define MyAppName "Radiomarker"
#define MyAppVersion "1.0.3"
#define MyAppPublisher "Radiomarker"

[Setup]
AppId={{A196B945-8F2C-4B9E-9D1A-7E6F3B2C8901}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=RadiomarkerSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: "desktophtml"; Description: "Creer un raccourci vers l'interface HTML sur le Bureau"; GroupDescription: "Raccourcis:"; Flags: unchecked

[Files]
Source: "..\reaper_lua_markers\*.lua"; DestDir: "{code:GetRadiomarkerLuaDir}"; Flags: ignoreversion
Source: "..\podcast_4pistes.html"; DestDir: "{code:GetRadiomarkerBaseDir}"; Flags: ignoreversion

[Icons]
Name: "{userdesktop}\Radiomarker interface HTML"; Filename: "{code:GetHtmlPath}"; Tasks: desktophtml

[Code]
var
  ReaperResourcePage: TInputDirWizardPage;

const
  RadiomarkerStartupSentinel = '-- Radiomarker bootstrap (installer)';

function NormalizeResourceRoot: String;
begin
  Result := RemoveBackslash(ReaperResourcePage.Values[0]);
end;

function GetRadiomarkerBaseDir(Param: string): string;
begin
  Result := AddBackslash(NormalizeResourceRoot) + 'Scripts\Radiomarker';
end;

function GetRadiomarkerLuaDir(Param: string): string;
begin
  Result := AddBackslash(GetRadiomarkerBaseDir('')) + 'reaper_lua_markers';
end;

function GetHtmlPath(Param: string): string;
begin
  Result := AddBackslash(GetRadiomarkerBaseDir('')) + 'podcast_4pistes.html';
end;

procedure InitializeWizard;
begin
  ReaperResourcePage := CreateInputDirPage(wpWelcome,
    'Dossier ressources REAPER',
    'Indique le dossier ressources utilise par REAPER.',
    'Installation classique : le chemin par defaut convient souvent (AppData\Roaming\REAPER).'#13#10#13#10 +
    'REAPER portable : choisis le dossier de donnees de cette copie (celui qui contient ou contiendra le dossier Scripts).'#13#10#13#10 +
    'Pour continuer, clique sur Suivant. Pour choisir un autre dossier, utilise Parcourir.',
    False,
    '');
  ReaperResourcePage.Add('Dossier ressources REAPER :');
  ReaperResourcePage.Values[0] := ExpandConstant('{userappdata}\REAPER');
end;

function IsValidReaperResourcePath(const Root: String): Boolean;
begin
  { Racine du volume accessible ; REAPER peut creer Scripts plus tard }
  Result := (Length(Trim(Root)) >= 2) and DirExists(ExtractFileDrive(Root) + '\');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = ReaperResourcePage.ID then
  begin
    if not IsValidReaperResourcePath(NormalizeResourceRoot) then
    begin
      MsgBox('Chemin invalide ou inaccessible.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;
end;

function MergeReaperStartup: Boolean;
var
  ScriptsDir: String;
  StartupPath: String;
  Existing: AnsiString;
  Block: AnsiString;
begin
  Result := True;
  ScriptsDir := AddBackslash(NormalizeResourceRoot) + 'Scripts';
  StartupPath := AddBackslash(ScriptsDir) + '__startup.lua';

  Block :=
    '-- Radiomarker bootstrap (installer)' + #13#10 +
    'do' + #13#10 +
    '  local sep = package.config:sub(1, 1)' + #13#10 +
    '  local bootstrap = reaper.GetResourcePath() .. sep .. "Scripts" .. sep .. "Radiomarker" .. sep .. "reaper_lua_markers" .. sep .. "radiomarker_bootstrap.lua"' + #13#10 +
    '  if reaper.file_exists(bootstrap) then' + #13#10 +
    '    dofile(bootstrap)' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  try
    if FileExists(StartupPath) then
    begin
      LoadStringFromFile(StartupPath, Existing);
      if Pos(RadiomarkerStartupSentinel, Existing) > 0 then
      begin
        Log('Radiomarker: __startup.lua deja configure');
        Exit;
      end;
      Existing := Existing + #13#10 + #13#10 + Block;
      SaveStringToFile(StartupPath, Existing, False);
    end
    else
    begin
      SaveStringToFile(StartupPath, Block, False);
    end;
  except
    Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not MergeReaperStartup then
      MsgBox('Les fichiers sont copies, mais la fusion de Scripts\__startup.lua a echoue.'#13 +
        'Tu peux ajouter manuellement l appel a radiomarker_bootstrap.lua — voir README.',
        mbError, MB_OK);
  end;
end;
