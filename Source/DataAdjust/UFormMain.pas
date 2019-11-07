{*******************************************************************************
  ����: dmzn@163.com 2019-01-16
  ����: ����У��
*******************************************************************************}
unit UFormMain;

{$I Link.Inc}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  UTrayIcon, ComCtrls, StdCtrls, ExtCtrls, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit, cxTextEdit,
  cxMaskEdit, cxDropDownEdit, cxCalendar, cxLabel;

type
  TfFormMain = class(TForm)
    MemoLog: TMemo;
    StatusBar1: TStatusBar;
    Panel1: TPanel;
    Group1: TGroupBox;
    BtnConn: TButton;
    Group2: TGroupBox;
    cxLabel1: TcxLabel;
    EditStart: TcxDateEdit;
    cxLabel2: TcxLabel;
    EditEnd: TcxDateEdit;
    Group3: TGroupBox;
    EditMax: TcxTextEdit;
    GroupBox1: TGroupBox;
    BtnTotal: TButton;
    EditTime: TcxTextEdit;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure BtnConnClick(Sender: TObject);
    procedure BtnTotalClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    FTrayIcon: TTrayIcon;
    {*״̬��ͼ��*}
    FList: TStrings;
    procedure ShowLog(const nStr: string);
    //��ʾ��־
  public
    { Public declarations }
  end;

var
  fFormMain: TfFormMain;

implementation

{$R *.dfm}
uses
  IniFiles, Registry, ULibFun, UDataModule, USysLoger, UFormConn, UFormWait,
  DB, USysDB;

var
  gPath: string;               //����·��

resourcestring
  sHint               = '��ʾ';
  sConfig             = 'Config.Ini';
  sForm               = 'FormInfo.Ini';
  sDB                 = 'DBConn.Ini';
  sAutoStartKey       = 'RemotePrinter';

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TfFormMain, '����У��ҵ��', nEvent);
end;

//------------------------------------------------------------------------------
procedure TfFormMain.FormCreate(Sender: TObject);
begin
  Randomize;
  gPath := ExtractFilePath(Application.ExeName);
  InitGlobalVariant(gPath, gPath+sConfig, gPath+sForm, gPath+sDB);

  gSysLoger := TSysLoger.Create(gPath + 'Logs\');
  gSysLoger.LogSync := True;
  gSysLoger.LogEvent := ShowLog;

  FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.Hint := Caption;
  FTrayIcon.Visible := True;

  FList := TStringList.Create;
  LoadFormConfig(Self);
  
  EditStart.Date := Now();
  EditEnd.Date := Now();

  FDM.ADOConn.Close;
  FDM.ADOConn.ConnectionString := BuildConnectDBStr;
  //���ݿ�����
end;

procedure TfFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveFormConfig(Self);
  FList.Free;
end;

procedure TfFormMain.ShowLog(const nStr: string);
var nIdx: Integer;
begin
  MemoLog.Lines.BeginUpdate;
  try
    MemoLog.Lines.Insert(0, nStr);
    if MemoLog.Lines.Count > 100 then
     for nIdx:=MemoLog.Lines.Count - 1 downto 50 do
      MemoLog.Lines.Delete(nIdx);
  finally
    MemoLog.Lines.EndUpdate;
  end;
end;

//Desc: ����nConnStr�Ƿ���Ч
function ConnCallBack(const nConnStr: string): Boolean;
begin
  FDM.ADOConn.Close;
  FDM.ADOConn.ConnectionString := nConnStr;
  FDM.ADOConn.Open;
  Result := FDM.ADOConn.Connected;
end;

//Desc: ���ݿ�����
procedure TfFormMain.BtnConnClick(Sender: TObject);
begin
  if ShowConnectDBSetupForm(ConnCallBack) then
  begin
    FDM.ADOConn.Close;
    FDM.ADOConn.ConnectionString := BuildConnectDBStr;
    //���ݿ�����
  end;
end;

procedure TfFormMain.BtnTotalClick(Sender: TObject);
var nStr,nID: string;
    nIdx,nTime: Integer;
    nWeight,nF: Double;
    nMDate: TDateTime;
begin
  if IsNumber(EditMax.Text, True) then
       nWeight := StrToFloat(EditMax.Text)
  else nWeight := 0;

  if IsNumber(EditTime.Text, False) then
       nTime := StrToInt(EditTime.Text)
  else nTime := 0;

  ShowWaitForm(Self, '����ͳ��');
  try
    nStr := '��ʼͳ���쳣����: ';
    WriteLog(nStr + #13#10);

    nStr := '����: ����[ %s -> %s ] ��� <= %s ����.';
    nStr := Format(nStr, [Date2Str(EditStart.Date),
            Date2Str(EditEnd.Date + 1), EditMax.Text]);
    WriteLog(nStr);

    nStr := 'Select P_ID,P_Truck,P_MName,P_MValue,P_MDate From %s ' +
            'Where P_MDate>=''%s'' And P_MDate<''%s'' ' +
            'Order By P_Truck ASC,P_MDate ASC';
    nStr := Format(nStr, [sTable_PoundLog, Date2Str(EditStart.Date),
            Date2Str(EditEnd.Date + 1), EditMax.Text]);
    //xxxxx

    with FDM.SQLQuery(nStr, FDM.SQLTemp) do
    begin
      nStr := '���: %d �ʼ�¼.';
      nStr := Format(nStr, [RecordCount]);
      WriteLog(nStr);

      if RecordCount < 1 then Exit;
      nStr := '��ʼ��ӡ�쳣������ϸ: ';
      WriteLog(nStr + #13#10);

      nIdx := 1;
      First;
      
      while not Eof do
      begin
        nStr := FieldByName('P_Truck').AsString;
        nID := FieldByName('P_ID').AsString;
        nMDate := FieldByName('P_MDate').AsDateTime;
        nF := FieldByName('P_MValue').AsFloat * 1000;

        Next;
        if (not Eof) and
           (CompareText(nStr, FieldByName('P_Truck').AsString) = 0) and
           (FieldByName('P_MDate').AsDateTime - nMDate < (nTime / (24 * 3600))) then
        begin
          nF := Abs(nF - FieldByName('P_MValue').AsFloat * 1000);
          if nF <= nWeight then
          begin
            nStr := '%d.����:%s,%s ����:%s ����:%s ���:%.2f����';
            nStr := Format(nStr, [nIdx, nID, FieldByName('P_ID').AsString,
                    FieldByName('P_Truck').AsString,
                    FieldByName('P_MName').AsString, nF]);
            //xxxxx

            WriteLog(nStr);
            Inc(nIdx);
          end;
        end;
      end;
    end;
  finally
    CloseWaitForm;
  end;
end;

end.
