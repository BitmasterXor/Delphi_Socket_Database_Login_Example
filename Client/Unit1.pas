unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, ncSources,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.VCLUI.Wait, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, uTPLb_CryptographicLibrary, uTPLb_BaseNonVisualComponent,
  uTPLb_Codec;

type
  TForm1 = class(TForm)
    ncClientSource1: TncClientSource;
    Edit1: TEdit;
    Edit2: TEdit;
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Button2: TButton;
    Codec1: TCodec;
    CryptographicLibrary1: TCryptographicLibrary;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    function ncClientSource1HandleCommand(Sender: TObject; aLine: TncLine;
      aCmd: Integer; const aData: TBytes; aRequiresResult: Boolean;
      const aSenderComponent, aReceiverComponent: string): TBytes;
    procedure ncClientSource1Disconnected(Sender: TObject; aLine: TncLine);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    procedure SendAuthRequest(const Command: string);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses Unit2;

procedure TForm1.SendAuthRequest(const Command: string);
var
  Username, Password, EncryptedCommand: string;
begin
  // Get username and password from edit boxes
  Username := Trim(Edit1.Text);
  Password := Trim(Edit2.Text);

  // Basic validation
  if (Username = '') or (Password = '') then
  begin
    ShowMessage('Please enter both username and password');
    Exit;
  end;

  try
    // encrypt our command to send...
    self.Codec1.EncryptString(Command + '|' + Edit1.Text + '|' + Edit2.Text,
      EncryptedCommand, Tencoding.UTF8);
    // Format and send the authentication message
    ncClientSource1.ExecCommand(0, bytesof(EncryptedCommand));
  except
    on E: Exception do
    begin
      ShowMessage('Error sending request: ' + E.Message);
    end;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if self.ncClientSource1.Active = false then
  begin
    self.ncClientSource1.Host := 'localhost';
    self.ncClientSource1.Port := 3434;
    self.ncClientSource1.Active := true;
  end;
  SendAuthRequest('LOGIN');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if self.ncClientSource1.Active = false then
  begin
    self.ncClientSource1.Host := 'localhost';
    self.ncClientSource1.Port := 3434;
    self.ncClientSource1.Active := true;
  end;
  SendAuthRequest('REGISTER');
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  self.Codec1.Password :=
    'asdfasdf*(&(*&*(Y&*^786tw87qy8ery87wsf78876&8*%^&*%^&%';
end;

procedure TForm1.ncClientSource1Disconnected(Sender: TObject; aLine: TncLine);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Form2.Visible then
      begin
        Form2.Visible := false;
        Form1.Edit1.Clear;
        Form1.Edit2.Clear;
        Form1.Visible := true;
        ShowMessage('Disconnected from server, You will have to log back in!');
      end;
    end);
end;

function TForm1.ncClientSource1HandleCommand(Sender: TObject; aLine: TncLine;
aCmd: Integer; const aData: TBytes; aRequiresResult: Boolean;
const aSenderComponent, aReceiverComponent: string): TBytes;
var
  Data: string;
  sl: TStringList;
begin
  Data := StringOf(aData);
  sl := TStringList.Create;

  TThread.Queue(nil,
    procedure
    begin
      try
        sl.Delimiter := '|';
        sl.StrictDelimiter := true;
        sl.DelimitedText := Data;

        if sl[0] = 'SUCCESS' then
        begin
          self.Hide;
          Form2.Caption := 'Logged In As User [' + Edit1.Text + ']';
          Form2.Show;
        end
        else if sl[0] = 'FAILED' then
        begin
          ShowMessage('Failed to Login! Try Again!');
        end
        else if sl[0] = 'REGISTERSUCCESS' then
        begin
          Edit1.Clear;
          Edit2.Clear;
          ShowMessage('Registration Success You May Now Login!');
        end
        else if sl[0] = 'REGISTERFAILED' then
        begin
          ShowMessage('Registration Failure User already Exists!');
        end;
      finally
        sl.Free;
      end;
    end);
end;

end.
