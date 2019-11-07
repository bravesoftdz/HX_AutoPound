{*******************************************************************************
  ����: dmzn@163.com 2014-06-10
  ����: �ֶ�����ͨ����
*******************************************************************************}
unit UFramePoundManualItem;

{$I Link.Inc}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  UMgrPoundTunnels, UFrameBase, USysBusiness,
  {$IFDEF HYReader}UMgrRFID102,{$ELSE}UMgrJinMai915,{$ENDIF} cxGraphics,
  cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit,
  dxSkinsCore, dxSkinsDefaultPainters, Menus, ExtCtrls, cxCheckBox,
  StdCtrls, cxButtons, cxTextEdit, cxMaskEdit, cxDropDownEdit, cxLabel,
  ULEDFont;

type
  TfFrameManualPoundItem = class(TBaseFrame)
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
    BtnPreW: TcxButton;
    BtnInputTruck: TcxButton;
    BtnSave: TcxButton;
    BtnNext: TcxButton;
    Timer1: TTimer;
    PMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    CheckLock: TcxCheckBox;
    N4: TMenuItem;
    N5: TMenuItem;
    Label1: TcxLabel;
    Label2: TcxLabel;
    Label3: TcxLabel;
    Label4: TcxLabel;
    Label5: TcxLabel;
    Label6: TcxLabel;
    procedure Timer1Timer(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure N3Click(Sender: TObject);
    procedure BtnInputTruckClick(Sender: TObject);
    procedure BtnNextClick(Sender: TObject);
    procedure BtnPreWClick(Sender: TObject);
    procedure EditMValuePropertiesEditValueChanged(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure N5Click(Sender: TObject);
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
    FPoundItem: TPoundItem;
    //��������
    FPrePWeight: Double;
    FIsWeighting: Boolean;
    //���ر�ʶ
    FAllowedInputTruck: Boolean;
    //�����ֶ�
    procedure UpdateUIData(const nData: TPoundItem; const nAll: Boolean = True);
    //���½���
    procedure SetImageStatus(const nImage: TImage; const nOff: Boolean);
    procedure SetButtonStatus(const nHasCard: Boolean);
    //����״̬
    procedure SetTunnel(const nTunnel: PPTTunnelItem);
    //����ͨ��
    procedure OnPoundData(const nValue: Double);
    //��ȡ����
    {$IFDEF HYReader}
    procedure OnHYReaderEvent(const nReader: PHYReaderItem);
    {$ELSE}
    procedure OnReaderDataEvent(const nReader: PJMReaderItem);
    {$ENDIF}
    procedure OnReaderData(const nReader,nCard: string);
    //��ȡ����
    function VerifyPoundItem(const nItem: TPoundItem): string;
    function IsDataValid(const nHasM: Boolean): Boolean;
    //У������
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
  ULibFun, UAdjustForm, UFormInputbox, USysLoger, USysConst, USysPopedom,
  USysDB, UDataModule;
  
const
  cFlag_ON    = 10;
  cFlag_OFF   = 20;

class function TfFrameManualPoundItem.FrameID: integer;
begin
  Result := 0;
end;

procedure TfFrameManualPoundItem.OnCreateFrame;
begin
  inherited;
  FIsWeighting := False;
  FPoundTunnel := nil;

  FPrePWeight := 0;
  FAllowedInputTruck := False;
  SetButtonStatus(False);

  LoadMaterails(EditMID.Properties.Items);
  LoadProviders(EditPID.Properties.Items);
end;

procedure TfFrameManualPoundItem.OnDestroyFrame;
begin
  {$IFDEF HYReader}           
  if Assigned(gHYCardEvent) then
       gHYReaderManager.OnCardEvent := gHYCardEvent //�ָ��Զ�����
  else gHYReaderManager.StopReader;
  {$ELSE}
  gJMCardManager.StopRead;
  gJMCardManager.DelReceiver(FReceiver);
  {$ENDIF}
  gPoundTunnelManager.ClosePort(FPoundTunnel.FID);

  AdjustStringsItem(EditMID.Properties.Items, True);
  AdjustStringsItem(EditPID.Properties.Items, True); 
  inherited;
end;

//Desc: ���������ý��水ť״̬
procedure TfFrameManualPoundItem.SetButtonStatus(const nHasCard: Boolean);
begin
  BtnPreW.Enabled := nHasCard and (gPopedomManager.HasPopedom(PopedomItem, sPopedom_Add));
  BtnSave.Enabled := nHasCard and (FPrePWeight > 0);
  BtnInputTruck.Enabled := (not nHasCard) and FAllowedInputTruck;

  EditValue.Text := '0.00';
  //default value
  FIsWeighting := nHasCard;

  if Assigned(FPoundTunnel) then
  begin
    {$IFNDEF debug}
    if nHasCard then
         gPoundTunnelManager.ActivePort(FPoundTunnel.FID, OnPoundData, True)
    else gPoundTunnelManager.ClosePort(FPoundTunnel.FID);
    {$ENDIF}
  end;
end;

//Desc: ���½�������
procedure TfFrameManualPoundItem.UpdateUIData(const nData: TPoundItem;
 const nAll: Boolean);
var nBool: Boolean;
begin
  with nData do
  begin
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
procedure TfFrameManualPoundItem.SetImageStatus(const nImage: TImage;
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

procedure WriteSysLog(const nEvent: string);
begin
  gSysLoger.AddLog(TfFrameManualPoundItem, '�ֶ�����ҵ��', nEvent);
end;

//------------------------------------------------------------------------------
//Desc: ��������״̬
procedure TfFrameManualPoundItem.Timer1Timer(Sender: TObject);
var nFlag: Integer;
begin
  SetImageStatus(ImageGS, GetTickCount - FLastGS > 5 * 1000);
  SetImageStatus(ImageBT, GetTickCount - FLastBT > 5 * 1000);

  nFlag := ImageBQ.Tag;
  SetImageStatus(ImageBQ, GetTickCount - FLastBQ > 5 * 1000);

  if (nFlag <> ImageBQ.Tag) and (ImageBQ.Tag = cFlag_OFF) then
  begin
    SetButtonStatus(False);
    {$IFNDEF debug}
    gProberManager.CloseTunnel(FPoundTunnel.FProber);
    {$ENDIF}
  end; //�رճ���
end;

procedure TfFrameManualPoundItem.SetTunnel(const nTunnel: PPTTunnelItem);
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

  EditMID.Properties.ReadOnly := False;
  EditPID.Properties.ReadOnly := False;
  //�����޸�����

  FAllowedInputTruck := AllowedInputTruck;
  BtnInputTruck.Enabled := FAllowedInputTruck;
  //�����ֶ�¼�복��
  N5.Checked := FAllowedInputTruck;
  N5.Enabled := gPopedomManager.HasPopedom(PopedomItem, sPopedom_Edit);
  //�л��ֹ�¼��
  
  {$IFDEF HYReader}
  gHYReaderManager.OnCardEvent := OnHYReaderEvent;
  gHYReaderManager.StartReader;
  {$ELSE}
  FReceiver := gJMCardManager.AddReceiver(OnReaderDataEvent);
  gJMCardManager.StartRead;
  {$ENDIF}
end;

procedure TfFrameManualPoundItem.EditMValuePropertiesEditValueChanged(
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
  end;

  UpdateUIData(FPoundItem, False);
  //ui sync
end;

//Desc: ����or�ر��ֶ�����
procedure TfFrameManualPoundItem.N1Click(Sender: TObject);
begin
  N1.Checked := not N1.Checked;
  //status change
  
  if N1.Checked then
       gProberManager.OpenTunnel(FPoundTunnel.FProber)
  else gProberManager.CloseTunnel(FPoundTunnel.FProber)
end;

//Desc: ����or�ر��ֶ����복��
procedure TfFrameManualPoundItem.N5Click(Sender: TObject);
begin
  SetAllowedInputTruck(not N5.Checked);
  FAllowedInputTruck := AllowedInputTruck;

  N5.Checked := FAllowedInputTruck;
  BtnInputTruck.Enabled := FAllowedInputTruck and (not BtnPreW.Enabled);
end;

//Desc: �رճ���ҳ��
procedure TfFrameManualPoundItem.N3Click(Sender: TObject);
var nP: TWinControl;
begin
  nP := Parent;
  while Assigned(nP) do
  begin
    if (nP is TBaseFrame) and
       (TBaseFrame(nP).FrameID = cFI_FramePoundManual) then
    begin
      TBaseFrame(nP).Close();
      Exit;
    end;

    nP := nP.Parent;
  end;
end;

//Desc: ��֤���ص�Ԥ������
function TfFrameManualPoundItem.VerifyPoundItem(const nItem: TPoundItem): string;
var nLast: Integer;
begin
  Result := '';
  if nItem.FLastTime = 0 then Exit;

  nLast := Trunc((nItem.FServerNow - nItem.FLastTime) * 24 * 3600);
  if nLast < FPoundTunnel.FCardInterval then
  begin
    Result := '��վ[ %s.%s ]: ����[ %s ]��ȴ� %d �����ܹ���.';
    Result := Format(Result, [FPoundTunnel.FID, FPoundTunnel.FName,
              nItem.FTruck, FPoundTunnel.FCardInterval - nLast]);
    Exit;
  end;
end;

//Desc: �ֹ�¼�복��
procedure TfFrameManualPoundItem.BtnInputTruckClick(Sender: TObject);
var nStr,nTruck,nCard: string;
    nItem: TPoundItem;
begin
  nTruck := '';
  //init
  
  while True do
  begin
    if not ShowInputBox('������Ҫ���صĳ��ƺ���:', 'Ӧ��', nTruck) then Exit;
    //user cancel

    nStr := GetTruckCard(nTruck, nCard);
    if nStr = '' then
         Break
    else ShowMsg(nStr, sHint);
  end;

  if not ReadPoundItem(nCard, nItem, nStr, False, not CheckLock.Checked) then
  begin
    WriteSysLog(nStr);
    Exit;
  end;
  
  if nStr <> '' then
    ShowDlg(nStr, sHint);
  //xxxxx

  nStr := VerifyPoundItem(nItem);
  if nStr <> '' then
  begin
    ShowDlg(nStr, sHint);
    Exit;
  end;
  
  FPoundItem := nItem;
  FPrePWeight := nItem.FPValue;

  UpdateUIData(FPoundItem);
  SetButtonStatus(FPoundItem.FTruck <> '');
end;

{$IFDEF HYReader}
procedure TfFrameManualPoundItem.OnHYReaderEvent(const nReader: PHYReaderItem);
begin
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
end;
{$ELSE}
//Desc: ��ȡ������
procedure TfFrameManualPoundItem.OnReaderDataEvent(const nReader: PJMReaderItem);
begin
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
end;
{$ENDIF}

//Desc: ��Զ�࿨
procedure TfFrameManualPoundItem.OnReaderData(const nReader,nCard: string);
var nStr: string;
    nItem: TPoundItem;
begin
  if nReader <> FPoundTunnel.FReader then Exit;
  FLastBQ := GetTickCount;

  if FIsWeighting then Exit;
  //������
  if nCard <> FLastCard then
    FLastCardDone := 0;
  //�¿�ʱ����
  
  if GetTickCount - FLastCardDone < 10 * 1000 then Exit;
  //�ظ�ˢ��,�������Ч

  if not ReadPoundItem(nCard, nItem, nStr, False, not CheckLock.Checked) then
  begin
    WriteSysLog(nStr);
    Exit;
  end;

  FLastCard := nCard;
  FLastCardDone := GetTickCount;
  nStr := VerifyPoundItem(nItem);

  if nStr <> '' then
  begin
    WriteSysLog(nStr);
    Exit;
  end;

  FPoundItem := nItem;
  FPrePWeight := nItem.FPValue;
  
  UpdateUIData(FPoundItem);
  SetButtonStatus(True);
end;

procedure TfFrameManualPoundItem.OnPoundData(const nValue: Double);
begin
  FLastBT := GetTickCount;
  EditValue.Text := Format('%.2f', [nValue]);;

  if CheckLock.Checked or (FPrePWeight <= 0) then
       FPoundItem.FPValue := nValue
  else FPoundItem.FMValue := nValue;

  UpdateUIData(FPoundItem, False);
  //ui sync
end;

//Desc: ����
procedure TfFrameManualPoundItem.BtnNextClick(Sender: TObject);
var nItem: TPoundItem;
begin
  FIsWeighting := False;
  FillChar(nItem, cSizePoundItem, #0);
  
  FPoundItem := nItem;
  FPrePWeight := 0;
  UpdateUIData(nItem);

  SetButtonStatus(False);
  CheckLock.Checked := False;
end;

//------------------------------------------------------------------------------
//Desc: ��֤�����Ƿ���Ч
function TfFrameManualPoundItem.IsDataValid(const nHasM: Boolean): Boolean;
begin
  Result := False;

  if EditMID.ItemIndex < 0 then
  begin
    EditMID.SetFocus;
    ShowMsg('��ѡ������', sHint); Exit;
  end;

  if EditPID.ItemIndex < 0 then
  begin
    EditPID.SetFocus;
    ShowMsg('��ѡ��ͻ�', sHint); Exit;
  end;

  with FPoundItem do
  begin
    if FPValue <= 0 then
    begin
      ShowMsg('Ƥ�ز���Ϊ0', sHint);
      Exit;
    end;

    if nHasM and (FMValue <= 0) then
    begin
      ShowMsg('ë�ز���Ϊ0', sHint);
      Exit;
    end;

    if nHasM and (FMValue < FPValue) then
    begin
      ShowMsg('Ƥ�ز��ܴ���ë��', sHint);
      Exit;
    end;

    FMate := GetStringsItemData(EditMID.Properties.Items, EditMID.ItemIndex);
    FMName := EditMID.Text;

    FProvider := GetStringsItemData(EditPID.Properties.Items, EditPID.ItemIndex);
    FPName := EditPID.Text;
  end;

  Result := True;
end;

//Desc: Ԥ��Ƥ��
procedure TfFrameManualPoundItem.BtnPreWClick(Sender: TObject);
var nStr: string;
begin
  if IsDataValid(False) and SavePreWeight(FPoundItem) then
  begin
    nStr := '�ͻ�:[ %s ] ����:[ %s ] Ƥ��:[ %.2f ]';
    with FPoundItem do
      nStr := Format(nStr, [FPName, FMName, FPValue]);
    FDM.WriteSysLog('Ԥ��Ƥ��', FPoundItem.FTruck, nStr);

    FPoundItem.FFixPound := FPoundTunnel.FID;
    AfterSavePoundItem(FPoundItem, FPoundTunnel);
    
    BtnNextClick(nil);
    ShowMsg('Ԥ�óɹ�', sHint);
  end;
end;

//Desc: �������
procedure TfFrameManualPoundItem.BtnSaveClick(Sender: TObject);
begin
  if IsDataValid(True) and SavePoundWeight(FPoundItem, FPoundTunnel) then
  begin
    AfterSavePoundItem(FPoundItem, FPoundTunnel);
    if CompareText(FPoundItem.FFixPound, FPoundTunnel.FID) = 0 then
      ShowMsg('���سɹ�', sHint);
    BtnNextClick(nil);
  end;
end;

end.
