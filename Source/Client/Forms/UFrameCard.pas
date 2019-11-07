{*******************************************************************************
  ����: dmzn@163.com 2012-04-07
  ����: ����ſ�
*******************************************************************************}
unit UFrameCard;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls,
  IniFiles, UFrameNormal, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxStyles, dxSkinsCore, dxSkinsDefaultPainters,
  cxCustomData, cxFilter, cxData, cxDataStorage, cxEdit, DB, cxDBData,
  cxContainer, Menus, dxLayoutControl, cxMaskEdit, cxButtonEdit,
  cxTextEdit, ADODB, cxLabel, UBitmapPanel, cxSplitter, cxGridLevel,
  cxClasses, cxGridCustomView, cxGridCustomTableView, cxGridTableView,
  cxGridDBTableView, cxGrid, ComCtrls, ToolWin;

type
  TfFrameBillCard = class(TfFrameNormal)
    cxTextEdit1: TcxTextEdit;
    dxLayout1Item1: TdxLayoutItem;
    EditCard: TcxButtonEdit;
    dxLayout1Item3: TdxLayoutItem;
    EditDate: TcxButtonEdit;
    dxLayout1Item6: TdxLayoutItem;
    cxTextEdit2: TcxTextEdit;
    dxLayout1Item4: TdxLayoutItem;
    PMenu1: TPopupMenu;
    N1: TMenuItem;
    N5: TMenuItem;
    N6: TMenuItem;
    N7: TMenuItem;
    N8: TMenuItem;
    N9: TMenuItem;
    N10: TMenuItem;
    N11: TMenuItem;
    N12: TMenuItem;
    N13: TMenuItem;
    N14: TMenuItem;
    N15: TMenuItem;
    N16: TMenuItem;
    N17: TMenuItem;
    EditTruck: TcxButtonEdit;
    dxLayout1Item8: TdxLayoutItem;
    procedure EditDatePropertiesButtonClick(Sender: TObject;
      AButtonIndex: Integer);
    procedure EditTruckPropertiesButtonClick(Sender: TObject;
      AButtonIndex: Integer);
    procedure BtnAddClick(Sender: TObject);
    procedure N5Click(Sender: TObject);
    procedure N6Click(Sender: TObject);
    procedure N8Click(Sender: TObject);
    procedure PMenu1Popup(Sender: TObject);
    procedure N9Click(Sender: TObject);
    procedure N10Click(Sender: TObject);
    procedure N11Click(Sender: TObject);
    procedure N12Click(Sender: TObject);
    procedure N14Click(Sender: TObject);
    procedure N15Click(Sender: TObject);
    procedure BtnDelClick(Sender: TObject);
    procedure N17Click(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure EditCardPropertiesButtonClick(Sender: TObject;
      AButtonIndex: Integer);
    procedure EditCardKeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
  protected
    FStart,FEnd: TDate;
    //ʱ������
    procedure OnCreateFrame; override;
    procedure OnDestroyFrame; override;
    function InitFormDataSQL(const nWhere: string): string; override;
    {*��ѯSQL*}
  public
    { Public declarations }
    class function FrameID: integer; override;
  end;

implementation

{$R *.dfm}
uses
  ULibFun, UMgrControl, UFormBase, USysDataDict, USysConst, USysDB, USysGrid,
  UDataModule, UFormDateFilter, U900Reader;

//------------------------------------------------------------------------------
class function TfFrameBillCard.FrameID: integer;
begin
  Result := cFI_FrameCard;
end;

procedure TfFrameBillCard.OnCreateFrame;
begin
  inherited;
  InitDateRange(Name, FStart, FEnd);
end;

procedure TfFrameBillCard.OnDestroyFrame;
begin
  SaveDateRange(Name, FStart, FEnd);
  inherited;
end;

function TfFrameBillCard.InitFormDataSQL(const nWhere: string): string;
begin
  EditDate.Text := Format('%s �� %s', [Date2Str(FStart), Date2Str(FEnd)]);

  Result := 'Select * From $CD cd ';
  //xxxxx

  if nWhere = '' then
       Result := Result + 'Where (C_Date>=''$S'' and C_Date<''$End'')'
  else Result := Result + 'Where (' + nWhere + ')';

  Result := MacroValue(Result, [MI('$CD', sTable_Card),
          MI('$S', Date2Str(FStart)), MI('$End', Date2Str(FEnd + 1))]);
  //xxxxx
end;

//------------------------------------------------------------------------------
//Desc: ˢ��
procedure TfFrameBillCard.BtnRefreshClick(Sender: TObject);
begin
  FWhere := '';
  InitFormData(FWhere);
end;

//Date: 2014-06-09
//Parm: ��¼��
//Desc: ΪnTruck���µĴſ�
function BindTruckCard(const nRID: string): Boolean;
var nP: TFormCommandParam;
begin
  nP.FCommand := cCmd_EditData;
  nP.FParamA := nRID;

  CreateBaseFormItem(cFI_FormBindCard, '', @nP);
  Result := (nP.FCommand = cCmd_ModalResult) and (nP.FParamA = mrOK);
end;

//Desc: ����
procedure TfFrameBillCard.BtnAddClick(Sender: TObject);
begin
  if BindTruckCard('') then
  begin
    InitFormData(FWhere);
    ShowMsg('����ɹ�', sHint);
  end;
end;

//Desc ɾ��
procedure TfFrameBillCard.BtnDelClick(Sender: TObject);
var nStr,nSQL: string;
begin
  if cxView1.DataController.GetSelectedCount < 1 then
  begin
    ShowMsg('��ѡ��Ҫɾ���Ĵſ�', sHint); Exit;
  end;

  nStr := SQLQuery.FieldByName('C_Status').AsString;
  if (nStr <> sFlag_CardIdle) and (nStr <> sFlag_CardInvalid) then
  begin
    ShowMsg('���л�ע��������ɾ��', sHint); Exit;
  end;

  nStr := SQLQuery.FieldByName('C_Freeze').AsString;
  if nStr = sFlag_Yes then
  begin
    ShowMsg('�ÿ��Ѿ�������', sHint); Exit;
  end;

  nSQL := 'ȷ��Ҫ�Կ�[ %s ]ִ��ɾ��������?';
  nStr := SQLQuery.FieldByName('C_Card').AsString;

  nSQL := Format(nSQL, [nStr]);
  if not QueryDlg(nSQL, sAsk) then Exit;

  nSQL := 'Delete From %s Where C_Card=''%s''';
  nSQL := Format(nSQL, [sTable_Card, nStr]);
  FDM.ExecuteSQL(nSQL);

  InitFormData(FWhere);
  ShowMsg('ɾ�������ɹ�', sHint);
end;

//Desc: ����ɸѡ
procedure TfFrameBillCard.EditDatePropertiesButtonClick(Sender: TObject;
  AButtonIndex: Integer);
begin
  if ShowDateFilterForm(FStart, FEnd) then InitFormData(FWhere);
end;

//Desc: ִ�в�ѯ
procedure TfFrameBillCard.EditTruckPropertiesButtonClick(Sender: TObject;
  AButtonIndex: Integer);
begin
  if Sender = EditCard then
  begin
    EditCard.Text := Trim(EditCard.Text);
    if EditCard.Text = '' then Exit;

    FWhere := 'C_Card like ''%%%s%%'' Or C_Card2 like ''%%%s%%''';
    FWhere := Format(FWhere, [EditCard.Text, EditCard.Text]);
    InitFormData(FWhere);
  end else

  if Sender = EditTruck then
  begin
    EditTruck.Text := Trim(EditTruck.Text);
    if EditTruck.Text = '' then Exit;

    FWhere := 'C_Truck like ''%' + EditTruck.Text + '%''';
    InitFormData(FWhere);
  end;
end;

procedure TfFrameBillCard.EditCardPropertiesButtonClick(Sender: TObject;
  AButtonIndex: Integer);
begin
  EditCard.Text := g900MReader.ReadCard(ParentForm, False, cCard_M1);
  EditTruckPropertiesButtonClick(Sender, AButtonIndex);
end;

procedure TfFrameBillCard.EditCardKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    EditTruckPropertiesButtonClick(Sender, 0);
  end;
end;

//Desc: ��Ч�ſ�
procedure TfFrameBillCard.N5Click(Sender: TObject);
begin
  FWhere := Format('C_Status=''%s''', [sFlag_CardInvalid]);
  InitFormData(FWhere);
end;

//Desc: ȫ���ſ�
procedure TfFrameBillCard.N6Click(Sender: TObject);
begin
  FWhere := '1=1';
  InitFormData(FWhere);
end;

//Desc: ����ſ�
procedure TfFrameBillCard.N8Click(Sender: TObject);
begin
  FWhere := Format('C_Freeze=''%s''', [sFlag_Yes]);
  InitFormData(FWhere);
end;

//------------------------------------------------------------------------------
//Desc: ���Ʋ˵���
procedure TfFrameBillCard.PMenu1Popup(Sender: TObject);
var nStr: string;
    i,nCount: integer;
begin
  nCount := PMenu1.Items.Count - 1;
  for i:=0 to nCount do
    PMenu1.Items[i].Enabled := False;
  //xxxxx
  
  N1.Enabled := True;
  N17.Enabled := cxView1.DataController.GetSelectedCount > 0;
  //��ע��Ϣ

  if (cxView1.DataController.GetSelectedCount > 0) and BtnAdd.Enabled then
  begin
    nStr := SQLQuery.FieldByName('C_Status').AsString;
    N9.Enabled := nStr = sFlag_CardUsed;
    //ʹ���еĿ����Թ�ʧ
    N10.Enabled := nStr = sFlag_CardLoss;
    //�ѹ�ʧ�����Խ��ʧ
    N11.Enabled := nStr = sFlag_CardLoss;
    //�ѹ�ʧ�����Բ��쿨
    N12.Enabled := nStr <> sFlag_CardInvalid;
    //����ʱ����
  end;

  if (cxView1.DataController.GetSelectedCount > 0) and BtnEdit.Enabled then
  begin
    nStr := SQLQuery.FieldByName('C_Freeze').AsString;
    N14.Enabled := nStr <> sFlag_Yes;   //����
    N15.Enabled := nStr = sFlag_Yes;    //���
  end;
end;

//Desc: ��ʧ�ſ�
procedure TfFrameBillCard.N9Click(Sender: TObject);
var nStr,nSQL: string;
begin
  nSQL := 'ȷ��Ҫ�Կ�[ %s ]ִ�й�ʧ������?';
  nStr := SQLQuery.FieldByName('C_Card').AsString;

  nSQL := Format(nSQL, [nStr]);
  if not QueryDlg(nSQL, sAsk) then Exit;

  nSQL := 'Update %s Set C_Status=''%s'' Where C_Card=''%s''';
  nSQL := Format(nSQL, [sTable_Card, sFlag_CardLoss, nStr]);
  FDM.ExecuteSQL(nSQL);

  InitFormData(FWhere);
  ShowMsg('��ʧ�����ɹ�', sHint);
end;

//Desc: �����ʧ
procedure TfFrameBillCard.N10Click(Sender: TObject);
var nStr,nSQL: string;
begin
  nSQL := 'ȷ��Ҫ�Կ�[ %s ]ִ�н����ʧ������?';
  nStr := SQLQuery.FieldByName('C_Card').AsString;

  nSQL := Format(nSQL, [nStr]);
  if not QueryDlg(nSQL, sAsk) then Exit;

  nSQL := 'Update %s Set C_Status=''%s'' Where C_Card=''%s''';
  nSQL := Format(nSQL, [sTable_Card, sFlag_CardUsed, nStr]);
  FDM.ExecuteSQL(nSQL);

  InitFormData(FWhere);
  ShowMsg('�����ʧ�����ɹ�', sHint);
end;

//Desc: ����ſ�
procedure TfFrameBillCard.N11Click(Sender: TObject);
begin
  if BindTruckCard(SQLQuery.FieldByName('R_ID').AsString) then
  begin
    InitFormData(FWhere);
    ShowMsg('���������ɹ�', sHint);
  end;
end;

//Desc: ע���ſ�
procedure TfFrameBillCard.N12Click(Sender: TObject);
var nStr,nCard: string;
begin
  nCard := SQLQuery.FieldByName('C_Card').AsString;
  nStr := Format('ȷ��Ҫ�Կ�[ %s ]ִ������������?', [nCard]);
  if not QueryDlg(nStr, sAsk) then Exit;

  nStr := 'Update %s Set C_Status=''%s'' Where C_Card=''%s''';
  nStr := Format(nStr, [sTable_Card, sFlag_CardInvalid, nCard]);
  FDM.ExecuteSQL(nStr);

  InitFormData(FWhere);
  ShowMsg('ע�������ɹ�', sHint);
end;

//Desc: ����ſ�
procedure TfFrameBillCard.N14Click(Sender: TObject);
var nStr,nSQL: string;
begin
  nSQL := 'ȷ��Ҫ�Կ�[ %s ]ִ�ж��������?';
  nStr := SQLQuery.FieldByName('C_Card').AsString;

  nSQL := Format(nSQL, [nStr]);
  if not QueryDlg(nSQL, sAsk) then Exit;

  nSQL := 'Update %s Set C_Freeze=''%s'' Where C_Card=''%s''';
  nSQL := Format(nSQL, [sTable_Card, sFlag_Yes, nStr]);
  FDM.ExecuteSQL(nSQL);

  InitFormData(FWhere);
  ShowMsg('��������ɹ�', sHint);
end;

//Desc: �������
procedure TfFrameBillCard.N15Click(Sender: TObject);
var nStr,nSQL: string;
begin
  nSQL := 'ȷ��Ҫ�Կ�[ %s ]ִ�н�����������?';
  nStr := SQLQuery.FieldByName('C_Card').AsString;

  nSQL := Format(nSQL, [nStr]);
  if not QueryDlg(nSQL, sAsk) then Exit;

  nSQL := 'Update %s Set C_Freeze=''%s'' Where C_Card=''%s''';
  nSQL := Format(nSQL, [sTable_Card, sFlag_No, nStr]);
  FDM.ExecuteSQL(nSQL);

  InitFormData(FWhere);
  ShowMsg('�����������ɹ�', sHint);
end;

//Desc: �޸ı�ע
procedure TfFrameBillCard.N17Click(Sender: TObject);
var nStr: string;
    nP: TFormCommandParam;
begin
  if BtnEdit.Enabled then
  begin
    nP.FCommand := cCmd_EditData;
    nP.FParamA := SQLQuery.FieldByName('C_Memo').AsString;
    nP.FParamB := 500;

    nStr := SQLQuery.FieldByName('R_ID').AsString;
    nP.FParamC := 'Update %s Set C_Memo=''$Memo'' Where R_ID=%s';
    nP.FParamC := Format(nP.FParamC, [sTable_Card, nStr]);

    CreateBaseFormItem(cFI_FormMemo, '', @nP);
    if (nP.FCommand = cCmd_ModalResult) and (nP.FParamA = mrOK) then
      InitFormData(FWhere);
    //xxxxx
  end else
  begin
    nP.FCommand := cCmd_ViewData;
    nP.FParamA := SQLQuery.FieldByName('C_Memo').AsString;
    CreateBaseFormItem(cFI_FormMemo, '', @nP);
  end;;
end;

initialization
  gControlManager.RegCtrl(TfFrameBillCard, TfFrameBillCard.FrameID);
end.
