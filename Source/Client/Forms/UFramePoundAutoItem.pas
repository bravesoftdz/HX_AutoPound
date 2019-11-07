{*******************************************************************************
  ����: dmzn@163.com 2014-06-10
  ����: �Զ�����ͨ����
*******************************************************************************}
unit UFramePoundAutoItem;

{$I Link.Inc}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  UMgrPoundTunnels, UFrameBase, USysBusiness,
  {$IFDEF HYReader}UMgrRFID102,{$ELSE}UMgrJinMai915,{$ENDIF} cxGraphics,
  cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit,
  dxSkinsCore, dxSkinsDefaultPainters, ExtCtrls, StdCtrls, UTransEdit,
  cxTextEdit, cxMaskEdit, cxDropDownEdit, cxLabel, ULEDFont;

type
  TfFrameAutoPoundItem = class(TBaseFrame)
    GroupBox1: TGroupBox;
    EditValue: TLEDFontNum;
    GroupBox3: TGroupBox;
    ImageGS: TImage;
    Label16: TLabel;
    Label17: TLabel;
    ImageBT: TImage;
    Label18: TLabel;
    ImageBQ: TImage;
    ImageOff: TImage;
    ImageOn: TImage;
    HintLabel: TcxLabel;
    EditTruck: TcxComboBox;
    EditMID: TcxComboBox;
    EditPID: TcxComboBox;
    EditMValue: TcxTextEdit;
    EditPValue: TcxTextEdit;
    EditJValue: TcxTextEdit;
    MemoLog: TZnTransMemo;
    Timer1: TTimer;
    TimerDelay: TTimer;
    TimerStart: TTimer;
    Label1: TcxLabel;
    Label2: TcxLabel;
    Label3: TcxLabel;
    Label4: TcxLabel;
    Label5: TcxLabel;
    Label6: TcxLabel;
    procedure Timer1Timer(Sender: TObject);
    procedure EditMValuePropertiesEditValueChanged(Sender: TObject);
    procedure EditValueDblClick(Sender: TObject);
    procedure TimerDelayTimer(Sender: TObject);
    procedure TimerStartTimer(Sender: TObject);
  private
    { Private declarations }
    FReceiver: Integer;
    //���Ž���
    FLastGS,FLastBT,FLastBQ: Int64;
    //�ϴλ
    FLastCardDone: Int64;
    FLastCard: string;
    //�ϴο���
    FPoundTunnel: PPTTunnelItem;
    //��վͨ��
    FPoundItem,FItemSaved: TPoundItem;
    //��������
    FIsWeighting: Boolean;
    //���ر�ʶ
    FSampleIndex: Integer;
    FValueSamples: array of Double;
    //���ݲ���
    procedure UpdateUIData(const nData: TPoundItem; const nAll: Boolean = True);
    //���½���
    procedure SetImageStatus(const nImage: TImage; const nOff: Boolean);
    procedure SetButtonStatus(const nHasCard: Boolean);
    //����״̬
    procedure InitTunnelData;
    procedure SetTunnel(const nTunnel: PPTTunnelItem);
    //����ͨ��
    procedure OnPoundData(const nValue: Double);
    procedure OnPoundDataEvent(const nValue: Double);
    //��ȡ����
    {$IFDEF HYReader}
    procedure OnHYReaderEvent(const nReader: PHYReaderItem);
    {$ELSE}
    procedure OnReaderDataEvent(const nReader: PJMReaderItem);
    {$ENDIF}
    procedure OnReaderData(const nReader,nCard: string);
    //��ȡ����
    function IsDataValid(const nHasM: Boolean): Boolean;
    //У������
    procedure InitSamples;
    procedure AddSample(const nValue: Double);
    function IsValidSamaple: Boolean;
    //�������
    procedure WriteLog(nEvent: string);
    //��¼��־
  public
    { Public declarations }
    class function FrameID: integer; override;
    procedure OnCreateFrame; override;
    procedure OnDestroyFrame; override;
    //����̳�
    property PoundTunnel: PPTTunnelItem read FPoundTunnel write SetTunnel;
    //�������
  end;

implementation

{$R *.dfm}

uses
  {$IFDEF OldTruckProber}UMgrTruckProbe_1,{$ELSE}UMgrTruckProbe,{$ENDIF}
  ULibFun, UTaskMonitor, UAdjustForm, USysDB, USysLoger, USysConst;

const
  cFlag_ON    = 10;
  cFlag_OFF   = 20;

class function TfFrameAutoPoundItem.FrameID: integer;
begin
  Result := 0;
end;

procedure TfFrameAutoPoundItem.OnCreateFrame;
begin
  inherited;
  FIsWeighting := False;
  FPoundTunnel := nil;

  SetButtonStatus(False);
  //init ui
end;

procedure TfFrameAutoPoundItem.OnDestroyFrame;
begin
  {$IFDEF HYReader}
  gHYReaderManager.StopReader;
  gHYCardEvent := nil;
  {$ELSE}
  gJMCardManager.StopRead;
  gJMCardManager.DelReceiver(FReceiver);
  {$ENDIF}

  gPoundTunnelManager.ClosePort(FPoundTunnel.FID);
  inherited;
end;

//Desc: ���������ý���
procedure TfFrameAutoPoundItem.SetButtonStatus(const nHasCard: Boolean);
begin
  EditValue.Text := '0.00';
  //default value
  FIsWeighting := nHasCard;

  if not nHasCard then
    InitTunnelData;
  UpdateUIData(FPoundItem, True);

  if Assigned(FPoundTunnel) then
  begin
    {$IFNDEF debug}
    if nHasCard then
         gPoundTunnelManager.ActivePort(FPoundTunnel.FID, OnPoundDataEvent, True)
    else gPoundTunnelManager.ClosePort(FPoundTunnel.FID);
    {$ENDIF}
  end;
end;

//Desc: ���½�������
procedure TfFrameAutoPoundItem.UpdateUIData(const nData: TPoundItem;
 const nAll: Boolean);
var nBool: Boolean;
begin
  with nData do
  begin
    if not Assigned(FPoundTunnel) then Exit;
    nBool := FPoundTunnel.FUserInput;
    FPoundTunnel.FUserInput := False;
    //������������

    if nAll then
    begin
      EditTruck.Text := FTruck;
      EditMID.Text := FMName;
      EditPID.Text := FPName;
    end;

    EditPValue.Text := Format('%.2f', [FPValue]);
    EditMValue.Text := Format('%.2f', [FMValue]);

    if FMValue > 0 then
         EditJValue.Text := Format('%.2f', [FMValue - FPValue])
    else EditJValue.Text := '0.00';

    FPoundTunnel.FUserInput := nBool;
    //��ԭ����
  end;
end;

//Desc: ��������״̬ͼ��
procedure TfFrameAutoPoundItem.SetImageStatus(const nImage: TImage;
  const nOff: Boolean);
begin
  if nOff then
  begin
    if nImage.Tag <> cFlag_OFF then
    begin
      nImage.Tag := cFlag_OFF;
      nImage.Picture.Bitmap := ImageOff.Picture.Bitmap;
    end;
  end else
  begin
    if nImage.Tag <> cFlag_ON then
    begin
      nImage.Tag := cFlag_ON;
      nImage.Picture.Bitmap := ImageOn.Picture.Bitmap;
    end;
  end;
end;

procedure TfFrameAutoPoundItem.WriteLog(nEvent: string);
var nInt: Integer;
begin
  with MemoLog do
  try
    Lines.BeginUpdate;
    if Lines.Count > 20 then
     for nInt:=1 to 10 do
      Lines.Delete(0);
    //�������

    Lines.Add(DateTime2Str(Now) + #9 + nEvent);
  finally
    Lines.EndUpdate;
    Perform(EM_SCROLLCARET,0,0);
    Application.ProcessMessages;
  end;
end;

procedure WriteSysLog(const nEvent: string);
begin
  gSysLoger.AddLog(TfFrameAutoPoundItem, '�Զ�����ҵ��', nEvent);
end;

//------------------------------------------------------------------------------
//Desc: ��������״̬
procedure TfFrameAutoPoundItem.Timer1Timer(Sender: TObject);
var nFlag: Integer;
begin
  SetImageStatus(ImageGS, GetTickCount - FLastGS > 5 * 1000);
  SetImageStatus(ImageBT, GetTickCount - FLastBT > 5 * 1000);

  nFlag := ImageBQ.Tag;
  SetImageStatus(ImageBQ, GetTickCount - FLastBQ > 3 * 1000);

  if (nFlag <> ImageBQ.Tag) and (ImageBQ.Tag = cFlag_OFF) then
  begin
    SetButtonStatus(False);
    gProberManager.CloseTunnel(FPoundTunnel.FProber);
  end; //�رճ���
end;

procedure TfFrameAutoPoundItem.InitTunnelData;
var nItem: TPoundItem;
begin
  FillChar(nItem, cSizePoundItem, #0);
  FPoundItem := nItem;
end;

procedure TfFrameAutoPoundItem.SetTunnel(const nTunnel: PPTTunnelItem);
var nIdx: Integer;
begin
  FPoundTunnel := nTunnel;
  //xxxxx

  for nIdx:=ControlCount - 1 downto 0 do
  begin
    if Controls[nIdx] is TcxComboBox then
     with (Controls[nIdx] as TcxComboBox) do
      Properties.ReadOnly := not nTunnel.FUserInput;
    //xxxxx

    if Controls[nIdx] is TcxTextEdit then
     with (Controls[nIdx] as TcxTextEdit) do
      Properties.ReadOnly := not nTunnel.FUserInput;
    //xxxxx
  end;

  {$IFDEF HYReader}
  gHYReaderManager.OnCardEvent := OnHYReaderEvent;
  gHYReaderManager.StartReader;
  gHYCardEvent := OnHYReaderEvent;
  {$ELSE}
  FReceiver := gJMCardManager.AddReceiver(OnReaderDataEvent);
  gJMCardManager.StartRead;
  {$ENDIF}
end;

//Desc: �ֶ�����
procedure TfFrameAutoPoundItem.EditMValuePropertiesEditValueChanged(
  Sender: TObject);
begin
  if not FPoundTunnel.FUserInput then Exit;
  //���û�����

  if Sender = EditMValue then
  begin
    if IsNumber(EditMValue.Text, True) then
         FPoundItem.FMValue := StrToFloat(EditMValue.Text)
    else FPoundItem.FMValue := 0;
  end else

  if Sender = EditPValue then
  begin
    if IsNumber(EditPValue.Text, True) then
         FPoundItem.FPValue := StrToFloat(EditPValue.Text)
    else FPoundItem.FPValue := 0;
  end else

  if Sender = EditTruck then
  begin
    FPoundItem.FTruck := EditTruck.Text;
  end else

  if Sender = EditMID then
  begin
    FPoundItem.FMate := EditMID.Text;
  end else

  if Sender = EditPID then
  begin
    FPoundItem.FProvider := EditPID.Text;
  end;

  UpdateUIData(FPoundItem, False);
  //ui sync
end;

//------------------------------------------------------------------------------
//Desc: ��֤�����Ƿ���Ч
function TfFrameAutoPoundItem.IsDataValid(const nHasM: Boolean): Boolean;
var nStr: string;
begin
  Result := False;

  with FPoundItem do
  begin
    if FTruck = '' then
    begin
      WriteLog('���ƺ�Ϊ�ղ��ܳ���.');
      nStr := '��վ[ %s.%s ]: ���ƺ�Ϊ��.';

      nStr := Format(nStr, [FPoundTunnel.FID, FPoundTunnel.FName]);
      WriteSysLog(nStr);
      Exit;
    end;

    if FMate = '' then
    begin
      WriteLog('����Ϊ�ղ��ܳ���.');
      nStr := '��վ[ %s.%s ]: ���Ϻ�Ϊ��.';

      nStr := Format(nStr, [FPoundTunnel.FID, FPoundTunnel.FName]);
      WriteSysLog(nStr);
      Exit;
    end;

    if FPValue <= 0 then
    begin
      WriteLog('Ƥ��Ϊ0���ܳ���,��Ԥ��Ƥ��.');
      nStr := '��վ[ %s.%s ]: ����Ƥ��Ϊ��.';

      nStr := Format(nStr, [FPoundTunnel.FID, FPoundTunnel.FName]);
      WriteSysLog(nStr);
      Exit;
    end;

    if nHasM and (FMValue <= 0) then
    begin
      WriteLog('ë��Ϊ0���ܳ���,�����ͷ����.');
      nStr := '��վ[ %s.%s ]: ����ë��Ϊ��.';

      nStr := Format(nStr, [FPoundTunnel.FID, FPoundTunnel.FName]);
      WriteSysLog(nStr);
      Exit;
    end;

    if nHasM and (FMValue < FPValue) then
    begin
      WriteLog('ë�ز��ܴ���Ƥ��,�߼�����.');
      nStr := '��վ[ %s.%s ]: �߼�����,ë��%.2f > Ƥ��%.2f';

      nStr := Format(nStr, [FPoundTunnel.FID, FPoundTunnel.FName,
                           FMValue, FPValue]);
      WriteSysLog(nStr);
      Exit;
    end;
  end;

  Result := True;
end;

//Desc: �ֶ���֤����
procedure TfFrameAutoPoundItem.EditValueDblClick(Sender: TObject);
begin
  IsDataValid(True);
end;

//------------------------------------------------------------------------------
{$IFDEF HYReader}
procedure TfFrameAutoPoundItem.OnHYReaderEvent(const nReader: PHYReaderItem);
var nTask: Int64;
begin
  nTask := gTaskMonitor.AddTask('�������ǩҵ��.', 5000);
  //new task

  try
    OnReaderData(nReader.FID, AdjustHYCard(nReader.FCard));
  except
    on E: Exception do
    begin
      WriteSysLog(Format('��վ[ %s.%s ]: %s', [FPoundTunnel.FID,
                                               FPoundTunnel.FName, E.Message]));
      //loged
    end;
  end;

  gTaskMonitor.DelTask(nTask);
  //task done
end; 
{$ELSE}
//Desc: ��ȡ������
procedure TfFrameAutoPoundItem.OnReaderDataEvent(const nReader: PJMReaderItem);
var nTask: Int64;
begin
  nTask := gTaskMonitor.AddTask('�������ǩҵ��.', 5000);
  //new task

  try
    OnReaderData(nReader.FID, nReader.FCard);
  except
    on E: Exception do
    begin
      WriteSysLog(Format('��վ[ %s.%s ]: %s', [FPoundTunnel.FID,
                                               FPoundTunnel.FName, E.Message]));
      //loged
    end;
  end;

  gTaskMonitor.DelTask(nTask);
  //task done
end;
{$ENDIF}

//Desc: �ذ�����
procedure TfFrameAutoPoundItem.OnPoundDataEvent(const nValue: Double);
var nTask: Int64;
begin
  nTask := gTaskMonitor.AddTask('����ذ�����.', 10 * 1000);
  //new task

  try
    OnPoundData(nValue);
  except
    on E: Exception do
    begin
      WriteSysLog(Format('��վ[ %s.%s ]: %s', [FPoundTunnel.FID,
                                               FPoundTunnel.FName, E.Message]));
      //loged
    end;
  end;

  gTaskMonitor.DelTask(nTask);
  //task done
end;

//Desc: ��Զ�࿨
procedure TfFrameAutoPoundItem.OnReaderData(const nReader,nCard: string);
var nStr: string;
    nLast: Integer;
    nItem: TPoundItem;
begin
  if nReader <> FPoundTunnel.FReader then Exit;
  FLastBQ := GetTickCount;

  if gSysParam.FIsManual then
  begin
    FIsWeighting := False;
    Exit;
  end; //�ֶ�ʱ��Ч

  if FIsWeighting then Exit;
  //������
  
  if nCard <> FLastCard then
    FLastCardDone := 0;
  //�¿�ʱ����

  if GetTickCount - FLastCardDone < 5 * 1000 then Exit;
  //�ظ�ˢ��,�������Ч

  FLastCard := nCard;
  FLastCardDone := GetTickCount;
  WriteLog('���յ�����: ' + nCard);
      
  if not ReadPoundItem(nCard, nItem, nStr) then
  begin
    WriteLog(nStr);
    //loged

    nStr := Format('��վ[ %s.%s ]: ',[FPoundTunnel.FID,
            FPoundTunnel.FName]) + nStr;
    WriteSysLog(nStr);
    Exit;
  end;

  if (nItem.FPTime = 0) or (nItem.FPValue <= 0) then
  begin
    WriteLog('Ƥ��Ϊ0���ܳ���,��Ԥ��Ƥ��.');
    nStr := '��վ[ %s.%s ]: ����Ƥ��Ϊ��.';
    nStr := Format(nStr, [FPoundTunnel.FID, FPoundTunnel.FName]);
    WriteSysLog(nStr); Exit;
  end;

  nLast := Trunc((nItem.FServerNow - nItem.FLastTime) * 24 * 3600);
  if nLast < FPoundTunnel.FCardInterval then
  begin
    nStr := '����[ %s ]��ȴ� %d �����ܹ���';
    nStr := Format(nStr, [nItem.FTruck, FPoundTunnel.FCardInterval - nLast]);
    WriteLog(nStr);

    nStr := Format('��վ[ %s.%s ]: ',[FPoundTunnel.FID,
            FPoundTunnel.FName]) + nStr;
    WriteSysLog(nStr);
    Exit;
  end;

  InitSamples;
  FPoundItem := nItem;
  TimerStart.Enabled := True;
end;

procedure TfFrameAutoPoundItem.TimerStartTimer(Sender: TObject);
var nStr: string;
    nTask: Int64;
begin
  TimerStart.Enabled := False;
  nTask := gTaskMonitor.AddTask('��ʼ����ҵ��.', 5000);
  //new task

  try
    SetButtonStatus(True); 
    nStr := Format('��ʼ�Գ���[ %s ]����.', [FPoundItem.FTruck]);
    WriteLog(nStr);
  except
    on E: Exception do
    begin
      WriteSysLog(Format('��վ[ %s.%s ]: %s', [FPoundTunnel.FID,
                                               FPoundTunnel.FName, E.Message]));
      //loged
    end;
  end;

  gTaskMonitor.DelTask(nTask);
  //task done
end;

procedure TfFrameAutoPoundItem.OnPoundData(const nValue: Double);
begin
  FLastBT := GetTickCount;
  EditValue.Text := Format('%.2f', [nValue]);

  if not FIsWeighting then Exit;
  //���ڳ�����
  if gSysParam.FIsManual then Exit;
  //�ֶ�ʱ��Ч

  FPoundItem.FMValue := nValue;
  UpdateUIData(FPoundItem, False);
  //ui sync

  if ImageBQ.Tag = cFlag_On then
  begin
    AddSample(nValue);
    if not (IsValidSamaple and IsDataValid(True)) then Exit;
    //��֤��ͨ��

    if GetTickCount - FLastCardDone < 3 * 1000 then Exit;
    FLastCardDone := GetTickCount;
    //�ظ�ˢ��,�������Ч

    if SavePoundWeight(FPoundItem, FPoundTunnel) then
    begin
      FItemSaved := FPoundItem;
      FIsWeighting := False;
      TimerDelay.Enabled := True;
    end;
  end; 
end;

//Desc: ��ʱ�������
procedure TfFrameAutoPoundItem.TimerDelayTimer(Sender: TObject);
begin
  try
    TimerDelay.Enabled := False;
    FLastCardDone := GetTickCount;
    WriteLog(Format('�Գ���[ %s ]�������.', [FItemSaved.FTruck]));

    AfterSavePoundItem(FItemSaved, FPoundTunnel);
    SetButtonStatus(False);
  except
    on E: Exception do
    begin
      WriteSysLog(Format('��վ[ %s.%s ]: %s', [FPoundTunnel.FID,
                                               FPoundTunnel.FName, E.Message]));
      //loged
    end;
  end;
end;

//Desc: ��ʼ������
procedure TfFrameAutoPoundItem.InitSamples;
var nIdx: Integer;
begin
  SetLength(FValueSamples, FPoundTunnel.FSampleNum);
  FSampleIndex := Low(FValueSamples);

  for nIdx:=High(FValueSamples) downto FSampleIndex do
    FValueSamples[nIdx] := 0;
  //xxxxx
end;

//Desc: ��Ӳ���
procedure TfFrameAutoPoundItem.AddSample(const nValue: Double);
begin
  FValueSamples[FSampleIndex] := nValue;
  Inc(FSampleIndex);

  if FSampleIndex >= FPoundTunnel.FSampleNum then
    FSampleIndex := Low(FValueSamples);
  //ѭ������
end;

//Desc: ��֤�����Ƿ��ȶ�
function TfFrameAutoPoundItem.IsValidSamaple: Boolean;
var nIdx: Integer;
    nVal: Integer;
begin
  Result := False;

  for nIdx:=FPoundTunnel.FSampleNum-1 downto 1 do
  begin
    if FValueSamples[nIdx] < 1 then Exit;
    //����������

    nVal := Trunc(FValueSamples[nIdx] * 1000 - FValueSamples[nIdx-1] * 1000);
    if Abs(nVal) >= FPoundTunnel.FSampleFloat then Exit;
    //����ֵ����
  end;

  Result := True;
end;

end.
