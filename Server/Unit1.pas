unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.VCLUI.Wait,
  Vcl.StdCtrls, ncSources, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  System.IOUtils, FireDAC.Phys.SQLiteWrapper.Stat, ncsocketlist, Vcl.ComCtrls,
  uTPLb_CryptographicLibrary, uTPLb_BaseNonVisualComponent, uTPLb_Codec;

type
  TForm1 = class(TForm)
    FDQuery1: TFDQuery;
    FDConnection1: TFDConnection;
    ncServerSource1: TncServerSource;
    Memo1: TMemo;
    GroupBox1: TGroupBox;
    StatusBar1: TStatusBar;
    Codec1: TCodec;
    CryptographicLibrary1: TCryptographicLibrary;
    procedure FormCreate(Sender: TObject);
    function ncServerSource1HandleCommand(Sender: TObject; aLine: TncLine;
      aCmd: Integer; const aData: TBytes; aRequiresResult: Boolean;
      const aSenderComponent, aReceiverComponent: string): TBytes;
    procedure ncServerSource1Connected(Sender: TObject; aLine: TncLine);
    procedure ncServerSource1Disconnected(Sender: TObject; aLine: TncLine);
  private
    FDatabasePath: string;
    procedure InitializeDatabase;
    procedure LogMessage(const Msg: string; const MsgType: string = 'INFO');
    function HandleLogin(const Username, Password: string): Boolean;
    function HandleRegister(const Username, Password: string): Boolean;
    function CheckDatabaseExists: Boolean;
    function CreateUsersTable: Boolean;
  public
    ClientsOnline: integer;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
//setup encryption password...
self.Codec1.Password:='asdfasdf*(&(*&*(Y&*^786tw87qy8ery87wsf78876&8*%^&*%^&%';


  FDatabasePath := TPath.Combine(TPath.GetDocumentsPath, 'DB.db');
  LogMessage('Starting server initialization...', 'SYSTEM');
  InitializeDatabase;

  try
    ncServerSource1.Port := 3434;
    ncServerSource1.Active := True;
    LogMessage('Server successfully started on port 3434', 'SYSTEM');
  except
    on E: Exception do
      LogMessage('Failed to start server: ' + E.Message, 'ERROR');
  end;
end;

function TForm1.CheckDatabaseExists: Boolean;
begin
  Result := TFile.Exists(FDatabasePath);
  if Result then
    LogMessage('Database file found at: ' + FDatabasePath)
  else
    LogMessage('Database file not found, will create new database', 'SYSTEM');
end;

function TForm1.CreateUsersTable: Boolean;
begin
  Result := False;
  try
    FDConnection1.ExecSQL('CREATE TABLE IF NOT EXISTS Users (' +
      'Username TEXT PRIMARY KEY,' + 'Password TEXT NOT NULL,' +
      'Created DATETIME DEFAULT CURRENT_TIMESTAMP)');
    Result := True;
    LogMessage('Users table verified/created successfully');
  except
    on E: Exception do
    begin
      LogMessage('Failed to create Users table: ' + E.Message, 'ERROR');
      raise;
    end;
  end;
end;

procedure TForm1.InitializeDatabase;
begin
  try
    // Configure SQLite connection
    FDConnection1.Params.Clear;
    FDConnection1.Params.Database := FDatabasePath;
    FDConnection1.Params.DriverID := 'SQLite';

    // Check if database exists
    if not CheckDatabaseExists then
      LogMessage('Creating new database file', 'SYSTEM');

    // Connect to database
    try
      FDConnection1.Connected := True;
      LogMessage('Successfully connected to database');
    except
      on E: Exception do
      begin
        LogMessage('Database connection failed: ' + E.Message, 'ERROR');
        raise;
      end;
    end;

    // Verify/Create Users table
    if not CreateUsersTable then
      raise Exception.Create('Failed to initialize database schema');

    LogMessage('Database initialization completed successfully', 'SYSTEM');
  except
    on E: Exception do
    begin
      LogMessage('Database initialization failed: ' + E.Message, 'ERROR');
      raise;
    end;
  end;
end;

function TForm1.HandleRegister(const Username, Password: string): Boolean;
var
  EncryptedPassword: string;
begin
  Result := False;
  LogMessage(Format('Registration attempt for username: %s', [Username]));

  try
    // Check if username already exists
    FDQuery1.Close;
    FDQuery1.SQL.Text := 'SELECT COUNT(*) FROM Users WHERE Username = :username';
    FDQuery1.ParamByName('username').AsString := Username;
    FDQuery1.Open;

    if FDQuery1.Fields[0].AsInteger > 0 then
    begin
      LogMessage(Format('Registration failed: Username "%s" already exists',
        [Username]), 'WARNING');
      Exit;
    end;

    // Encrypt the password before storing
    Codec1.EncryptString(password, EncryptedPassword, TEncoding.UTF8);

    // Insert new user with encrypted password
    FDConnection1.ExecSQL(
      'INSERT INTO Users (Username, Password) VALUES (:username, :password)',
      [Username, EncryptedPassword]);

    Result := True;
    LogMessage(Format('New user registered successfully: %s', [Username]),
      'SUCCESS');
  except
    on E: Exception do
    begin
      LogMessage(Format('Registration error for user "%s": %s',
        [Username, E.Message]), 'ERROR');
      Result := False;
    end;
  end;
end;

function TForm1.HandleLogin(const Username, Password: string): Boolean;
var
  StoredEncryptedPassword, DecryptedStoredPassword: string;
begin
  LogMessage(Format('Login attempt for user: %s', [Username]));
  try
    FDQuery1.Close;
    FDQuery1.SQL.Text := 'SELECT Password FROM Users WHERE Username = :username';
    FDQuery1.ParamByName('username').AsString := Username;
    FDQuery1.Open;

    if not FDQuery1.EOF then
    begin
      // Get the encrypted password from database
      StoredEncryptedPassword := FDQuery1.FieldByName('Password').AsString;

      // Decrypt the stored password
      Codec1.DecryptString(DecryptedStoredPassword, StoredEncryptedPassword, TEncoding.UTF8);

      // Compare with provided password
      Result := DecryptedStoredPassword = Password;

      if Result then
        LogMessage(Format('User "%s" logged in successfully', [Username]))
      else
        LogMessage(Format('Login failed for user "%s": Invalid password', [Username]), 'WARNING');
    end
    else
    begin
      Result := False;
      LogMessage(Format('Login failed for user "%s": User not found', [Username]), 'WARNING');
    end;
  except
    on E: Exception do
    begin
      LogMessage(Format('Login error for user "%s": %s', [Username, E.Message]), 'ERROR');
      Result := False;
    end;
  end;
  FDQuery1.Close;
end;

procedure TForm1.LogMessage(const Msg: string; const MsgType: string = 'INFO');
const
  MAX_MEMO_LINES = 1000;
begin
  TThread.Synchronize(nil,
    procedure
    begin
      // Add timestamp and message type to log
      Memo1.Lines.Add(Format('[%s][%s] %s',
        [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), MsgType, Msg]));

      // Keep memo size under control
      if Memo1.Lines.Count > MAX_MEMO_LINES then
        Memo1.Lines.Delete(0);

      // Auto-scroll to bottom
      SendMessage(Memo1.Handle, EM_SCROLLCARET, 0, 0);
    end);
end;

procedure TForm1.ncServerSource1Connected(Sender: TObject; aLine: TncLine);
begin
self.ClientsOnline:= self.ClientsOnline + 1;
self.StatusBar1.Panels[0].Text := 'Users Online [' + inttostr(ClientsOnline) + ']';
LogMessage('User Connected From IP: ' + aLine.PeerIP);
end;

procedure TForm1.ncServerSource1Disconnected(Sender: TObject; aLine: TncLine);
begin
self.ClientsOnline:= self.ClientsOnline - 1;
self.StatusBar1.Panels[0].Text := 'Users Online [' + inttostr(ClientsOnline) + ']';
LogMessage('User Disconnected From IP: ' + aLine.PeerIP);
end;

function TForm1.ncServerSource1HandleCommand(Sender: TObject; aLine: TncLine;
aCmd: Integer; const aData: TBytes; aRequiresResult: Boolean;
const aSenderComponent, aReceiverComponent: string): TBytes;
var
  ReceivedCommand: string;
  sl: TStringList;
  DecryptedCommand:string;
begin
  ReceivedCommand := StringOf(aData);
  self.Codec1.DecryptString(DecryptedCommand,ReceivedCommand,Tencoding.UTF8);
  LogMessage('Received command: ' + DecryptedCommand);

  sl := TStringList.Create;

  TThread.Queue(nil,
    procedure
    var
      Response: string;
    begin
      try
        sl.Delimiter := '|';
        sl.StrictDelimiter := True;
        sl.DelimitedText := DecryptedCommand;

        if (sl.Count >= 3) then
        begin
          if sl[0] = 'LOGIN' then
          begin
            if HandleLogin(sl[1], sl[2]) then
              Response := 'SUCCESS|'
            else
              Response := 'FAILED|';
          end
          else if sl[0] = 'REGISTER' then
          begin
            if HandleRegister(sl[1], sl[2]) then
              Response := 'REGISTERSUCCESS|'
            else
              Response := 'REGISTERFAILED|';
          end
          else
          begin
            Response := 'INVALID_COMMAND';
            LogMessage('Invalid command received: ' + sl[0], 'WARNING');
          end;
        end
        else
        begin
          Response := 'INVALID_FORMAT';
          LogMessage('Invalid command format received', 'WARNING');
        end;

        LogMessage('Sending response: ' + Response);
        ncServerSource1.ExecCommand(aLine, 0, bytesof(Response), False);
      finally
        sl.Free;
      end;
    end);
end;

end.
