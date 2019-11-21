{*******************************************************************************
  ����: dmzn@163.com 2019-08-12
  ����: ���ó�������
*******************************************************************************}
unit UFormTruck;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, UFormNormal, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxContainer, cxEdit, cxLabel, cxTextEdit,
  dxLayoutControl, StdCtrls;

type
  TfFormTruck = class(TfFormNormal)
    EditPound: TcxTextEdit;
    dxLayout1Item3: TdxLayoutItem;
    EditNet: TcxTextEdit;
    dxLayout1Item4: TdxLayoutItem;
    EditTruck: TcxTextEdit;
    dxLayout1Item6: TdxLayoutItem;
    cxLabel1: TcxLabel;
    dxLayout1Item5: TdxLayoutItem;
    dxLayout1Group2: TdxLayoutGroup;
    procedure BtnOKClick(Sender: TObject);
  private
    { Private declarations }
    FRecords: string;
    //��¼���
    FPound: string;
    //ԭ�а�վ
    FTrucks: string;
    //�����б�
    FMaxNet: Double;
    //ԭ������
  public
    { Public declarations }
    class function CreateForm(const nPopedom: string = '';
      const nParam: Pointer = nil): TWinControl; override;
    class function FormID: integer; override;
    function SimpleTruck(const nTrucks: string): string;
  end;

implementation

{$R *.dfm}

uses
  IniFiles, ULibFun, UMgrControl, USysPopedom, UFormBase, USysDB, USysConst,
  USysBusiness, UDataModule;

class function TfFormTruck.CreateForm(const nPopedom: string;
  const nParam: Pointer): TWinControl;
var nBool: Boolean;
    nP: PFormCommandParam;
begin
  Result := nil;
  if Assigned(nParam) then
       nP := nParam
  else Exit;

  with TfFormTruck.Create(Application) do
  begin
    Caption := '��������';
    FRecords := nP.FParamA;
    FPound := nP.FParamB;
    FMaxNet := nP.FParamC;
    FTrucks := nP.FParamD;

    EditTruck.Text := SimpleTruck(FTrucks);
    EditPound.Text := FPound;
    EditNet.Text := FloatToStr(FMaxNet);

    nBool := gPopedomManager.HasPopedom(nPopedom, sPopedom_Add);
    EditNet.Properties.ReadOnly := not nBool;

    nP.FCommand := cCmd_ModalResult;
    nP.FParamA := ShowModal;
    Free;
  end;
end;

class function TfFormTruck.FormID: integer;
begin
  Result := cFI_FormSetTruck;
end;

function TfFormTruck.SimpleTruck(const nTrucks: string): string;
var nPos: Integer;
begin
  nPos := Pos(',', nTrucks);
  if nPos > 0 then
       Result := Copy(nTrucks, 1, nPos - 1) + '(��)'
  else Result := nTrucks;
end;

procedure TfFormTruck.BtnOKClick(Sender: TObject);
var nStr: string;
begin
  if (not IsNumber(EditNet.Text, True)) or (StrToFloat(EditNet.Text) < 0) then
  begin
    ShowMsg('��������Ч��ֵ', sHint);
    Exit;
  end;

  if EditNet.Properties.ReadOnly then //ֻ���°�վ
  begin
    nStr := 'Update %s Set T_FixPound=''%s'' Where R_ID In (%s)';
    nStr := Format(nStr, [sTable_Truck, EditPound.Text, FRecords]);
    FDM.ExecuteSQL(nStr);

    nStr := Format('��վ:[%s -> %s] ', [FPound, EditPound.Text]) +
            Format('����:[%s]', [FTrucks]);
    FDM.WriteSysLog('��������', EditTruck.Text, nStr);
  end else
  begin
    nStr := 'Update %s Set T_FixPound=''%s'',T_MaxWeight=%s Where R_ID In (%s)';
    nStr := Format(nStr, [sTable_Truck, EditPound.Text, EditNet.Text, FRecords]);
    FDM.ExecuteSQL(nStr);

    nStr := Format('��վ:[%s -> %s] ', [FPound, EditPound.Text]) +
            Format('����:[%.2f -> %s] ', [FMaxNet, EditNet.Text]) +
            Format('����:[%s]', [FTrucks]);
    FDM.WriteSysLog('��������', EditTruck.Text, nStr);
  end;

  ModalResult := mrOk;
end;

initialization
  gControlManager.RegCtrl(TfFormTruck, TfFormTruck.FormID);
end.
