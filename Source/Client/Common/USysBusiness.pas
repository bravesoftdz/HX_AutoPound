{*******************************************************************************
  ����: dmzn@163.com 2014-06-12
  ����: ҵ����Ԫ
*******************************************************************************}
unit USysBusiness;

{$I Link.inc}
interface

uses
  Windows, Classes, SysUtils, UDataModule, ULibFun, UFormCtrl, UAdjustForm,
  UMgrPoundTunnels, HKVNetSDK, UMgrRemoteVoice, UTaskMonitor,
  {$IFDEF OldTruckProber}UMgrTruckProbe_1,{$ELSE}UMgrTruckProbe,{$ENDIF}
  UMgrBXFontCard, USysLoger, USysDB, USysConst;

type
  PPoundItem = ^TPoundItem;
  TPoundItem = record
    FCard: string;                         //�ſ����
    FTruck: string;                        //���ƺ���
    FProvider,FPName: string;              //�ͻ���Ϣ
    FMate,FMName: string;                  //������Ϣ
    FPValue,FMValue: Double;               //����
    FPTime,FMTime: TDateTime;              //����ʱ��
    FPMan,FMMan: string;                   //������
    FLastPound: string;
    FLastTime: TDateTime;                  //�ϴγ���
    FFixPound: string;                     //ָ����վ
    FMaxWeight: Double;                    //��������
    FServerNow: TDateTime;                 //������ʱ��
  end;

const
  cSizePoundItem = SizeOf(TPoundItem);

function ReadPoundItem(const nCard: string; var nData: TPoundItem;
 var nHint: string; const nNeedPreW: Boolean = True;
 const nVerifyPreDate: Boolean = True): Boolean;
//��ȡ�ſ���Ϣ
procedure LoadMaterails(const nList: TStrings);
procedure LoadProviders(const nList: TStrings);
//������Ϣ�б�
function SavePreWeight(const nData: TPoundItem): Boolean;
//����Ԥ��Ƥ��
function SavePoundWeight(nData: TPoundItem; nTunnel: PPTTunnelItem;
  const nManualMode: Boolean = False): Boolean;
//�����������
function AfterSavePoundItem(nData: TPoundItem; nTunnel: PPTTunnelItem): Boolean;
//�������
function GetTruckCard(const nTruck: string; var nCard: string): string;
//��ȡnTruck�󶨵Ĵſ�
function AllowedInputTruck: Boolean;
procedure SetAllowedInputTruck(const nAllowed: Boolean);
//�ֹ����복��
function AdjustHYCard(const nCard: string): string;
//У�����˶������ſ���

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(nEvent);
end;

//Desc: ��nStatusתΪ�ɶ�����
function CardStatusToStr(const nStatus: string): string;
begin
  if nStatus = sFlag_CardIdle then Result := '����' else
  if nStatus = sFlag_CardUsed then Result := '����' else
  if nStatus = sFlag_CardLoss then Result := '��ʧ' else
  if nStatus = sFlag_CardInvalid then Result := 'ע��' else Result := 'δ֪';
end;

//Date: 2014-06-12
//Parm: �ſ���;����;��ʾ;��ҪԤ��Ƥ��;��֤Ԥ��ʱ��
//Desc: ��ȡnCard��Ϣ,����nData.���ش�������
function ReadPoundItem(const nCard: string; var nData: TPoundItem;
 var nHint: string; const nNeedPreW, nVerifyPreDate: Boolean): Boolean;
var nStr: string;
    nTask: Int64;
    nInt: Integer;
begin
  Result := False;
  nHint := '';

  nTask := gTaskMonitor.AddTask('��ȡ��ǩ��Ϣ[ ReadPoundItem ].', 5000);
  //new task

  FillChar(nData, cSizePoundItem, #0);
  try
    nStr := 'Select C_Status,C_Freeze,C_Truck From %s ' +
            'Where C_Card=''%s'' Or C_Card2=''%s''';
    nStr := Format(nStr, [sTable_Card, nCard, nCard]);

    with FDM.QueryTemp(nStr) do
    begin
      if RecordCount < 1 then
      begin
        nStr := '�ſ�[ %s ]��Ϣ��ʧ,����Ч.';
        nHint := Format(nStr, [nCard]);
        Exit;
      end;

      if Fields[0].AsString <> sFlag_CardUsed then
      begin
        nStr := '�ſ�[ %s ]��ǰ״̬Ϊ[ %s ],�޷�ʹ��.';
        nHint := Format(nStr, [nCard, CardStatusToStr(Fields[0].AsString)]);
        Exit;
      end;

      if Fields[1].AsString = sFlag_Yes then
      begin
        nStr := '�ſ�[ %s ]�ѱ�����,�޷�ʹ��.';
        nHint := Format(nStr, [nCard]);
        Exit;
      end;

      nData.FTruck := Fields[2].AsString;
    end;

    nStr := 'Select *,%s as T_Now From %s Where T_Truck=''%s''';
    nStr := Format(nStr, [sField_SQLServer_Now, sTable_Truck, nData.FTruck]);

    with FDM.QueryTemp(nStr) do
    begin
      if RecordCount < 1 then
      begin
        nStr := '����[ %s ]��Ϣ��ʧ,��Ԥ��Ƥ��.';
        nHint := Format(nStr, [nData.FTruck]);

        if not nNeedPreW then
          Result := True;
        Exit;
      end;

      with nData do
      begin
        FCard       := nCard;
        FProvider   := FieldByName('T_Provider').AsString;
        FPName      := FieldByName('T_PName').AsString;
        FMate       := FieldByName('T_Mate').AsString;
        FMName      := FieldByName('T_MName').AsString;
        FPValue     := FieldByName('T_PrePValue').AsFloat;
        FPTime      := FieldByName('T_PrePTime').AsDateTime;
        FPMan       := FieldByName('T_PrePMan').AsString;

        FFixPound   := FieldByName('T_FixPound').AsString;
        FMaxWeight  := FieldByName('T_MaxWeight').AsFloat;
        FLastPound  := FieldByName('T_LastPound').AsString;
        FLastTime   := FieldByName('T_LastTime').AsDateTime;
        FServerNow  := FieldByName('T_Now').AsDateTime;
      end;

      Result := True;
    end;

    if not nVerifyPreDate then Exit;
    //����֤Ԥ��ʱ��

    nStr := 'Select D_Value,D_ParamA,D_ParamB From %s ' +
            'Where D_Name=''%s'' And D_Memo=''%s''';
    nStr := Format(nStr, [sTable_SysDict, sFlag_SysParam, sFlag_PrePValidLen]);

    with FDM.QueryTemp(nStr) do
    begin
      if RecordCount < 1 then Exit;
      nStr := Trim(FieldByName('D_ParamB').AsString);

      if CompareText(nStr, sFlag_PrePValidMon) = 0 then //������Ч
      begin
        nStr := Copy(Date2Str(nData.FServerNow, False), 1, 6);
        //now month
        
        if nStr <> Copy(Date2Str(nData.FPTime, False), 1, 6) then
        begin
          nInt := Trunc(FieldByName('D_ParamA').AsFloat);
          //ÿ�¼���ǰ��Ч

          nStr := Copy(Date2Str(nData.FServerNow, False), 7, 2);
          //�����Ǽ���

          if nInt < StrToInt(nStr) then
          begin
            nStr := '����[ %s ]�ϴ�Ԥ��ʱ��Ϊ[ %s ],�ѹ���.';
            nHint := Format(nStr, [nData.FTruck, Date2Str(nData.FPTime)]);
            Result := False;
          end;
        end;

        Exit;
      end;

      nInt := Trunc(nData.FServerNow - nData.FPTime);
      if nInt > FieldByName('D_Value').AsInteger then
      begin
        nStr := '����[ %s ]�ϴ�Ԥ��ʱ��Ϊ[ %s ],�ѹ���.';
        nHint := Format(nStr, [nData.FTruck, Date2Str(nData.FPTime)]);
        Result := False;
      end;
    end;
  finally
    gTaskMonitor.DelTask(nTask);
    //move task
  end;
end;

//Desc: ��ȡԭ����
procedure LoadMaterails(const nList: TStrings);
var nStr: string;
begin
  nList.Clear;
  nStr := 'Select M_ID,M_Name From %s Order By M_Name';
  nStr := Format(nStr, [sTable_Materails]);

  with FDM.QueryTemp(nStr) do
  if RecordCount > 0 then
  begin
    First;

    while not Eof do
    begin
      nList.Add(Fields[0].AsString + '=' + Fields[1].AsString);
      Next;
    end;

    AdjustStringsItem(nList, False);
  end;
end;

//Desc: ��ȡ��Ӧ��
procedure LoadProviders(const nList: TStrings);
var nStr: string;
begin
  nList.Clear;
  nStr := 'Select P_ID,P_Name From %s Order By P_Name';
  nStr := Format(nStr, [sTable_Provider]);

  with FDM.QueryTemp(nStr) do
  if RecordCount > 0 then
  begin
    First;

    while not Eof do
    begin
      nList.Add(Fields[0].AsString + '=' + Fields[1].AsString);
      Next;
    end;

    AdjustStringsItem(nList, False);
  end;
end;

//Desc: ����Ԥ��Ƥ��
function SavePreWeight(const nData: TPoundItem): Boolean;
var nStr: string;
    nTask: Int64;
begin
  nTask := gTaskMonitor.AddTask('����Ԥ��Ƥ��[ SavePreWeight ].', 5000);
  try
    nStr := MakeSQLByStr([SF('T_Mate', nData.FMate),
            SF('T_MName', nData.FMName),
            SF('T_Provider', nData.FProvider),
            SF('T_PName', nData.FPName),
            SF('T_PrePValue', nData.FPValue, sfVal),
            SF('T_PrePMan', gSysParam.FUserID),
            SF('T_PrePTime', sField_SQLServer_Now, sfVal)],
            sTable_Truck, SF('T_Truck', nData.FTruck), False);
    //xxxxxx

    Result := FDM.ExecuteSQL(nStr) > 0;
    if Result then Exit;

    nStr := MakeSQLByStr([SF('T_Truck', nData.FTruck),
            SF('T_PY', GetPinYinOfStr(nData.FTruck)),
            SF('T_Mate', nData.FMate),
            SF('T_MName', nData.FMName),
            SF('T_Provider', nData.FProvider),
            SF('T_PName', nData.FPName),
            SF('T_PrePValue', nData.FPValue, sfVal),
            SF('T_PrePMan', gSysParam.FUserID),
            SF('T_PrePTime', sField_SQLServer_Now, sfVal),
            SF('T_LastTime', sField_SQLServer_Now, sfVal),
            SF('T_Valid', sFlag_Yes)], sTable_Truck, '', True);
    Result := FDM.ExecuteSQL(nStr) > 0;
  finally
    gTaskMonitor.DelTask(nTask);
  end;
end;

//Date: 2012-3-25
//Parm: ����;����;��������
//Desc: ��ȡnGroup.nObject��ǰ�ļ�¼���
function GetSerailID(const nGroup,nObject: string; const nTrans: Boolean): string;
var nStr,nP,nB: string;
begin
  if nTrans then FDM.ADOConn.BeginTrans;
  try
    nStr := 'Update %s Set B_Base=B_Base+1 ' +
            'Where B_Group=''%s'' And B_Object=''%s''';
    //xxxxx
    
    nStr := Format(nStr, [sTable_SerialBase, nGroup, nObject]);
    FDM.ExecuteSQL(nStr);

    nStr := 'Select B_Prefix,B_IDLen,B_Base From %s ' +
            'Where B_Group=''%s'' And B_Object=''%s''';
    nStr := Format(nStr, [sTable_SerialBase, nGroup, nObject]);

    with FDM.QueryTemp(nStr) do
    begin
      nP := Fields[0].AsString;
      nB := Fields[2].AsString;

      nStr := StringOfChar('0', Fields[1].AsInteger-Length(nP)-Length(nB));
      Result := nP + nStr + nB;
    end;

    if nTrans then FDM.ADOConn.CommitTrans;
  except
    if nTrans then
      FDM.ADOConn.RollbackTrans;
    raise;
  end;
end;

//Date: 2014-06-19
//Parm: ��¼��ʶ;���ƺ�;ͼƬ�ļ�
//Desc: ��nFile�������ݿ�
procedure SavePicture(const nID, nTruck, nMate, nFile: string);
var nStr: string;
    nTask: Int64;
    nRID: Integer;
begin
  nTask := gTaskMonitor.AddTask('����ץ��ͼƬ[ SavePicture ].', 5000);
  //new task

  FDM.ADOConn.BeginTrans;
  try
    nStr := MakeSQLByStr([
            SF('P_ID', nID),
            SF('P_Name', nTruck),
            SF('P_Mate', nMate),
            SF('P_Date', sField_SQLServer_Now, sfVal)
            ], sTable_Picture, '', True);
    //xxxxx

    if FDM.ExecuteSQL(nStr) < 1 then Exit;
    nRID := FDM.GetFieldMax(sTable_Picture, 'R_ID');

    nStr := 'Select P_Picture From %s Where R_ID=%d';
    nStr := Format(nStr, [sTable_Picture, nRID]);
    FDM.SaveDBImage(FDM.QueryTemp(nStr), 'P_Picture', nFile);

    FDM.ADOConn.CommitTrans;
  except
    FDM.ADOConn.RollbackTrans;
  end;

  gTaskMonitor.DelTask(nTask);
  //task done
end;

//Desc: ����ͼƬ·��
function MakePicName: string;
begin
  while True do
  begin
    Result := gSysParam.FPicPath + IntToStr(gSysParam.FPicBase) + '.jpg';
    if not FileExists(Result) then
    begin
      Inc(gSysParam.FPicBase);
      Exit;
    end;

    DeleteFile(Result);
    if FileExists(Result) then Inc(gSysParam.FPicBase)
  end;
end;

//Date: 2014-06-19
//Parm: ͨ��;�б�
//Desc: ץ��nTunnel��ͼ��
procedure CapturePicture(const nTunnel: PPTTunnelItem; const nList: TStrings);
const
  cRetry = 2;
  //���Դ���
var nStr: string;
    nIdx,nInt: Integer;
    nLogin,nErr: Integer;
    nPic: NET_DVR_JPEGPARA;
    nInfo: TNET_DVR_DEVICEINFO;
begin
  nList.Clear;
  if not Assigned(nTunnel.FCamera) then Exit;
  //not camera

  if not DirectoryExists(gSysParam.FPicPath) then
    ForceDirectories(gSysParam.FPicPath);
  //new dir

  if gSysParam.FPicBase >= 100 then
    gSysParam.FPicBase := 0;
  //clear buffer

  nLogin := -1;
  NET_DVR_Init();
  try
    for nIdx:=1 to cRetry do
    begin
      nLogin := NET_DVR_Login(PChar(nTunnel.FCamera.FHost),
                   nTunnel.FCamera.FPort,
                   PChar(nTunnel.FCamera.FUser),
                   PChar(nTunnel.FCamera.FPwd), @nInfo);
      //to login

      nErr := NET_DVR_GetLastError;
      if nErr = 0 then break;

      if nIdx = cRetry then
      begin
        nStr := '��¼�����[ %s.%d ]ʧ��,������: %d';
        nStr := Format(nStr, [nTunnel.FCamera.FHost, nTunnel.FCamera.FPort, nErr]);
        WriteLog(nStr);
        Exit;
      end;
    end;

    nPic.wPicSize := nTunnel.FCamera.FPicSize;
    nPic.wPicQuality := nTunnel.FCamera.FPicQuality;

    for nIdx:=Low(nTunnel.FCameraTunnels) to High(nTunnel.FCameraTunnels) do
    begin
      if nTunnel.FCameraTunnels[nIdx] = MaxByte then continue;
      //invalid

      for nInt:=1 to cRetry do
      begin
        nStr := MakePicName();
        //file path

        NET_DVR_CaptureJPEGPicture(nLogin, nTunnel.FCameraTunnels[nIdx],
                                   @nPic, PChar(nStr));
        //capture pic

        nErr := NET_DVR_GetLastError;
        if nErr = 0 then
        begin
          nList.Add(nStr);
          Break;
        end;

        if nIdx = cRetry then
        begin
          nStr := 'ץ��ͼ��[ %s.%d ]ʧ��,������: %d';
          nStr := Format(nStr, [nTunnel.FCamera.FHost,
                   nTunnel.FCameraTunnels[nIdx], nErr]);
          WriteLog(nStr);
        end;
      end;
    end;
  finally
    if nLogin > -1 then
      NET_DVR_Logout(nLogin);
    NET_DVR_Cleanup();
  end;
end;

//Date: 2014-06-21
//Parm: ��������;����ͨ��;�Ƿ��ֶ�����ģʽ
//Desc: ����nTunnel������nData���ݴ������ݿ�
function SavePoundWeight(nData: TPoundItem; nTunnel: PPTTunnelItem;
  const nManualMode: Boolean): Boolean;
var nStr,nID,nMode,nCZ: string;
    nIdx,nInt: Integer;
    nTask: Int64;
    nList: TStrings;
begin
  if CompareText(nData.FFixPound, nTunnel.FID) <> 0 then
  begin
    nStr := '����[ %s ]ֻ���ڰ�վ[ %s ]����.';
    nStr := Format(nStr, [nData.FTruck, nData.FFixPound]);
    WriteLog(nStr);

    Result := True;
    Exit;
  end;

  nTask := gTaskMonitor.AddTask('�������[ SavePoundWeight ].', 5000);
  //new task
  nID := GetSerailID(sFlag_SerailSYS, sFlag_PoundLog, True);
  //pound id

  with nData do
  begin
    if nData.FLastTime > 0 then
    begin
      nInt := Trunc((FDM.ServerNow - nData.FLastTime) * 24 * 60);
      if nInt >= 1000 then nInt := 0;
      //��������ϴ�ë�صļ��������,̫��������
    end else nInt := 0;

    if nManualMode then
         nMode := '����'
    else nMode := 'Ԥ��';

    if (FMaxWeight > 0) and (FPValue > 0) and (FMValue > 0) and
       FloatRelation(FMValue-FPValue, FMaxWeight, rtGreater) then
         nCZ := sFlag_Yes
    else nCZ := sFlag_No; //�Ƿ���

    nStr := MakeSQLByStr([SF('P_ID', nID),
            SF('P_Type', sFlag_Provide),
            SF('P_Truck', nData.FTruck),
            SF('P_MID', FMate),
            SF('P_MName', FMName),
            SF('P_MType', sFlag_PoundSan),
            SF('P_CusID', FProvider),
            SF('P_CusName', FPName),
            SF('P_PValue', FPValue, sfVal),
            SF('P_PDate', FPTime, sfDateTime),
            SF('P_PMan', FPMan),
            SF('P_MValue', FMValue, sfVal),
            SF('P_MDate', sField_SQLServer_Now, sfVal),
            SF('P_MMan', gSysParam.FUserID),
            SF('P_LastMDate', nData.FLastTime, sfDateTime),
            SF('P_LastInterval', nInt, sfVal),
            SF('P_FactID', nTunnel.FFactoryID),
            SF('P_Station', nTunnel.FID),
            SF('P_MAC', gSysParam.FLocalMAC),
            SF('P_Direction', '�ڲ�'),
            SF('P_PModel', nMode),
            SF('P_Valid', sFlag_Yes),
            SF('P_OverNet', nCZ),
            SF('P_PrintNum', 0, sfVal)], sTable_PoundLog, '', True);
    //xxxxx

    Result := FDM.ExecuteSQL(nStr) > 0;
    gTaskMonitor.DelTask(nTask);
    if not Result then Exit;

    if nManualMode then Exit;
    //�ֹ�¼��������º�ץ��

    nStr := 'Update %s Set T_LastPound=''%s'',T_LastTime=%s Where T_Truck=''%s''';
    nStr := Format(nStr, [sTable_Truck, nID, sField_SQLServer_Now, nData.FTruck]);
    FDM.ExecuteSQL(nStr);
  end;

  nTask := gTaskMonitor.AddTask('ץ��ͼƬ[ CapturePicture ].', 5000);
  //new task

  nList := TStringList.Create;
  try
    CapturePicture(nTunnel, nList);
    //capture file

    for nIdx:=0 to nList.Count - 1 do
      SavePicture(nID, nData.FTruck, nData.FMName, nList[nIdx]);
    //save file
  finally
    nList.Free;
    gTaskMonitor.DelTask(nTask);
  end;
end;

//Date: 2014-06-20
//Parm: ����;ͨ��
//Desc: ִ�����ݱ����Ķ���
function AfterSavePoundItem(nData: TPoundItem; nTunnel: PPTTunnelItem): Boolean;
var nStr: string;
    nTask: Int64;
begin
  nTask := gTaskMonitor.AddTask('�������̵�[ OpenTunnel ].', 5000);
  //new task

  Result := True;
  try
    if CompareText(nData.FFixPound, nTunnel.FID) = 0 then
    begin
      gVoiceHelper.PlayVoice(#9 + nData.FTruck);
      //��������
      gProberManager.OpenTunnel(nTunnel.FProber);
      //���̵�

      {$IFDEF BXFontCard}
      gBXFontCardManager.Display(Format('����%s�������', [nData.FTruck]),
        Format('����: %.2f��', [nData.FMValue]));
      {$ENDIF}
    end else
    begin
      nStr := '����%s�뻻%s������';
      nStr := Format(nStr, [nData.FTruck, nData.FFixPound]);
      gVoiceHelper.PlayVoice(nStr);

      {$IFDEF BXFontCard}
      gBXFontCardManager.Display(Format('����%s�������ɹ�', [nData.FTruck]),
        Format('�뻻%s������', [nData.FFixPound]));
      {$ENDIF}
    end;
  except
    on E: Exception do
    begin
      WriteLog(E.Message);
    end;
  end;

  gTaskMonitor.DelTask(nTask);
  //task done
end;

//Date: 2014-06-28
//Parm: ���ƺ�;����
//Desc: ��ȡnTruck�󶨵Ĵſ���
function GetTruckCard(const nTruck: string; var nCard: string): string;
var nStr: string;
begin
  Result := '';
  nStr := 'Select C_Card From %s Where C_Truck=''%s''';
  nStr := Format(nStr, [sTable_Card, nTruck]);

  with FDM.QueryTemp(nStr) do
  begin
    if RecordCount < 1 then
    begin
      Result := Format('����[ %s ]������', [nTruck]);
      Exit;
    end;

    nCard := Fields[0].AsString;
  end;
end;

//Desc: �Ƿ������ֶ����복��
function AllowedInputTruck: Boolean;
var nStr: string;
begin
  Result := False;
  nStr := 'Select D_Value From %s Where D_Name=''%s'' And D_Memo=''%s''';
  nStr := Format(nStr, [sTable_SysDict, sFlag_SysParam, sFlag_InputTruck]);

  with FDM.QueryTemp(nStr) do
  if RecordCount > 0 then
  begin
    Result := Fields[0].AsString = sFlag_Yes;
  end;
end;

//Date: 2014-06-28
//Parm: �Ƿ������ֶ�����
//Desc: �����ֶ��������
procedure SetAllowedInputTruck(const nAllowed: Boolean);
var nStr,nFlag: string;
begin
  if nAllowed then
       nFlag := sFlag_Yes
  else nFlag := sFlag_No;

  nStr := 'Update %s Set D_Value=''%s'' Where D_Name=''%s'' And D_Memo=''%s''';
  nStr := Format(nStr, [sTable_SysDict, nFlag, sFlag_SysParam, sFlag_InputTruck]);
  
  if FDM.ExecuteSQL(nStr) < 1 then
  begin
    nStr := MakeSQLByStr([SF('D_Name', sFlag_SysParam),
            SF('D_Memo', sFlag_InputTruck),
            SF('D_Value', nFlag),
            SF('D_Desc', '�����ֶ����복��')], sTable_SysDict, '', True);
    FDM.ExecuteSQL(nStr);
  end;
end;

//Date: 2019-08-07
//Parm: �ſ���
//Desc: �������˶������Ĵſ���
function AdjustHYCard(const nCard: string): string;
begin
  Result := Copy(nCard, Length(nCard) - 11, 12);
end;

end.
