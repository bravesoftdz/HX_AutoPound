{*******************************************************************************
  ����: dmzn@163.com 2020-01-15
  ����: �û�ȫ����ģ��
*******************************************************************************}
unit MainModule;

interface

uses
  uniGUIMainModule, SysUtils, Classes, Vcl.Graphics, Data.Win.ADODB, Data.DB,
  Datasnap.DBClient, System.Variants, uniGUIBaseClasses, uniGUIClasses,
  uniImageList, uniGUIForm, uniDBGrid, uniGUImForm, uniGUITypes, USysConst;

type
  TUniMainModule = class(TUniGUIMainModule)
    ImageListSmall: TUniNativeImageList;
    ImageListBar: TUniNativeImageList;
    procedure UniGUIMainModuleCreate(Sender: TObject);
    procedure UniGUIMainModuleDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    FMainForm: TUnimForm;
    //������
    FUserConfig: TSysParam;
    //ϵͳ����
    FGridColumnAdjust: Boolean;
    //��������
    FMenuModule: TMenuModuleItems;
    //�˵�ģ��
    procedure DoDefaultAdjustEvent(Sender: TComponent; nEventName: string;
      nParams: TUniStrings);
    //Ĭ���¼�
    procedure DoColumnFormat(Sender: TField; var Text: string;
      DisplayText: Boolean);
    procedure DoColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure DoColumnSummary(Column: TUniDBGridColumn;
      GroupFieldValue: Variant);
    procedure DoColumnSummaryResult(Column: TUniDBGridColumn;
      GroupFieldValue: Variant; Attribs: TUniCellAttribs; var Result: string);
    //������
  end;

function UniMainModule: TUniMainModule;

implementation

{$R *.dfm}

uses
  UniGUIVars, ServerModule, uniGUIApplication, USysBusiness;

function UniMainModule: TUniMainModule;
begin
  Result := TUniMainModule(UniApplication.UniMainModule)
end;

procedure TUniMainModule.UniGUIMainModuleCreate(Sender: TObject);
var nIdx: Integer;
begin
  FGridColumnAdjust := False;
  //Ĭ�ϲ��������������п���˳��

  FUserConfig := gSysParam;
  //����ȫ�ֲ���

  with FUserConfig,UniSession do
  begin
    FLocalIP   := RemoteIP;
    FLocalName := RemoteHost;
    FUserAgent := UserAgent;
    FOSUser    := SystemUser;
    FIsPhone   := upPhone in UniSession.UniPlatform;
  end;

  GlobalSyncLock;
  try
    //for nIdx := gAllUsers.Count-1 downto 0 do
    // if PSysParam(gAllUsers[nIdx]).FLocalIP = FUserConfig.FLocalIP then
    //  FUserConfig := PSysParam(gAllUsers[nIdx])^;
    //restore

    gAllUsers.Add(@FUserConfig);
  finally
    GlobalSyncRelease;
  end;

  SetLength(FMenuModule, gMenuModule.Count);
  for nIdx := 0 to gMenuModule.Count-1 do
    FMenuModule[nIdx] := PMenuModuleItem(gMenuModule[nIdx])^;
  //׼���˵�ģ��ӳ��
end;

procedure TUniMainModule.UniGUIMainModuleDestroy(Sender: TObject);
var nIdx: Integer;
begin
  GlobalSyncLock;
  try
    nIdx := gAllUsers.IndexOf(@FUserConfig);
    if nIdx >= 0 then
      gAllUsers.Delete(nIdx);
    //xxxxx
  finally
    GlobalSyncRelease;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2018-05-24
//Parm: �¼�;����
//Desc: Ĭ��Adjust����
procedure TUniMainModule.DoDefaultAdjustEvent(Sender: TComponent;
  nEventName: string; nParams: TUniStrings);
begin
  if nEventName = sEvent_StrGridColumnResize then
    DoStringGridColumnResize(Sender, nParams);
  //�û������п�
end;

//Desc: �ֶ����ݸ�ʽ��
procedure TUniMainModule.DoColumnFormat(Sender: TField; var Text: string;
  DisplayText: Boolean);
var nStr: string;
    nIdx,nInt: Integer;
begin
  GlobalSyncLock;
  try
    with gAllEntitys[Sender.DataSet.Tag].FDictItem[Sender.Tag] do
    begin
      nStr := Trim(Sender.AsString) + '=';
      if nStr = '=' then Exit;

      nIdx := Pos(nStr, FFormat.FData);
      if nIdx < 1 then Exit;

      nInt := nIdx + Length(nStr);     //start
      nStr := Copy(FFormat.FData, nInt, Length(FFormat.FData) - nInt + 1);

      nInt := Pos(';', nStr);
      if nInt < 2 then
           Text := nStr
      else Text := Copy(nStr, 1, nInt - 1);
    end;
  finally
    GlobalSyncRelease;
  end;
end;

//Desc: ����
procedure TUniMainModule.DoColumnSort(Column: TUniDBGridColumn;
  Direction: Boolean);
var nStr: string;
    nDS: TClientDataSet;
begin
  if TUniDBGrid(Column.Grid).DataSource.DataSet is TClientDataSet then
       nDS := TUniDBGrid(Column.Grid).DataSource.DataSet as TClientDataSet
  else Exit;

  if Direction then
       nStr := Column.FieldName + '_asc'
  else nStr := Column.FieldName + '_des';

  if nDS.IndexDefs.IndexOf(nStr) >= 0 then
    nDS.IndexName := nStr;
  //xxxxx
end;

//Desc: �ϼƼ���
procedure TUniMainModule.DoColumnSummary(Column: TUniDBGridColumn;
  GroupFieldValue: Variant);
begin
  GlobalSyncLock;
  try
    with gAllEntitys[Column.Grid.Tag].FDictItem[Column.Tag] do
    begin
      if FFooter.FKind = fkSum then //sum
      begin
        if Column.AuxValue = NULL then
             Column.AuxValue := Column.Field.AsFloat
        else Column.AuxValue := Column.AuxValue + Column.Field.AsFloat;
      end else

      if FFooter.FKind = fkCount then //count
      begin
        if Column.AuxValue = NULL then
             Column.AuxValue := 1
        else Column.AuxValue := Column.AuxValue + 1;
      end;
    end;
  finally
    GlobalSyncRelease;
  end;
end;

//Desc: �ϼƽ��
procedure TUniMainModule.DoColumnSummaryResult(Column: TUniDBGridColumn;
  GroupFieldValue: Variant; Attribs: TUniCellAttribs; var Result: string);
var nF: Double;
    nI: Integer;
begin
  GlobalSyncLock;
  try
    with gAllEntitys[Column.Grid.Tag].FDictItem[Column.Tag] do
    begin
      if FFooter.FKind = fkSum then //sum
      begin
        if Column.AuxValue = Null then Exit;
        nF := Column.AuxValue;
        Result := FormatFloat(FFooter.FFormat, nF );

        Attribs.Font.Style := [fsBold];
        Attribs.Font.Color := clNavy;
      end else

      if FFooter.FKind = fkCount then //count
      begin
        if Column.AuxValue = Null then Exit;
        nI := Column.AuxValue;
        Result := FormatFloat(FFooter.FFormat, nI);

        Attribs.Font.Style := [fsBold];
        Attribs.Font.Color := clNavy;
      end;
    end;

    Column.AuxValue := NULL;
  finally
    GlobalSyncRelease;
  end;
end;

initialization
  RegisterMainModuleClass(TUniMainModule);
end.