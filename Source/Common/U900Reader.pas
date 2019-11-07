{*******************************************************************************
  ����: dmzn@163.com 2014-06-09
  ����: ����900M���������ͨѶ��Ԫ
*******************************************************************************}
unit U900Reader;

interface

uses
  Windows, Classes, Forms, Messages, SysUtils, IniFiles, UFormWait, ULibFun,
  Uinterface;

type
  T900CardFlag = record
    FType: Integer;
    FFlag: string;
    FLength: Integer;
  end;

  T900MReader = class(TObject)
  private
    FCfgFile: string;
    //�����ļ�
    FConncted: Boolean;
    //�Ƿ�����
    FInit: Int64;
    FDelay: Integer; 
    //��ʱ��ȡ
    FFlags: array of T900CardFlag;
    //���Ŵ���
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    function GetRegularFlag(const nType: Integer): Integer;
    function GetCardNO(const nType: Integer = -1): string;
    function ReadCard(const nPForm: TForm; const nSendVK: Boolean = False;
      const nType: Integer = -1): string;
    //��ȡ����
    procedure SendKeyboard(const nHandle: THandle; const nStr: string);
    //ģ�����
    property Config: string read FCfgFile write FCfgFile;
    //�������
  end;

var
  g900MReader: T900MReader = nil;
  //ȫ��ʹ��

implementation

constructor T900MReader.Create;
begin
  FConncted := False;
end;

destructor T900MReader.Destroy;
begin
  if FConncted then
     CloseCommPort;
  inherited;
end;

//------------------------------------------------------------------------------
//Date: 2014-06-09
//Parm: ������;�Ƿ�ģ�����;��������
//Desc: ��ȡ�ſ���,��nPForm������ʾ������
function T900MReader.ReadCard(const nPForm: TForm; const nSendVK: Boolean;
  const nType: Integer): string;
var nStr: string;
    nList: TStrings;
    nIni: TIniFile;
    nIV: Int64;
    nInt: Integer;
begin
  Result := '';
  //init
  
  if not FConncted then
  begin
    if not FileExists(FCfgFile) then
      raise Exception.Create('��Ч��900M��ͷ�����ļ�.');
    //xxxxx

    nList := nil;
    nIni := TIniFile.Create(FCfgFile);
    try
      nStr := nIni.ReadString('Config', 'Enable', 'Y');
      if nStr = 'N' then Exit;

      nStr := nIni.ReadString('Config', 'Port', '');
      if nStr = '' then
        raise Exception.Create('��Ч��900M��ͷͨѶ�˿�����.');
      //xxxxx

      if OpenCommPort(PChar(nStr)) <> 1 then
      begin
        nStr := Format( '�޷���900M��ͷͨѶ�˿�.', [nStr]);
        raise Exception.Create(nStr);
      end;

      nList := TStringList.Create;
      nIni.ReadSections(nList);
      SetLength(FFlags, 0);

      for nInt:=nList.Count - 1 downto 0 do
      begin
        nStr := nIni.ReadString(nList[nInt], 'Type', '');
        if (nStr = '') or (not IsNumber(nStr, False)) then continue;

        nIV := Length(FFlags);
        SetLength(FFlags, nIV + 1);

        with FFlags[nIV] do
        begin
          FType := StrToInt(nStr);
          FFlag := nIni.ReadString(nList[nInt], 'Flag', '');
          FLength := nIni.ReadInteger(nList[nInt], 'Length', 12);
        end;
      end;

      FDelay := nIni.ReadInteger('Config', 'Delay', 5);
      //������ʱ
      FConncted := True;
    finally
      nList.Free;
      nIni.Free;
    end;   
  end; 

  ShowWaitForm(nPForm, '������');
  try
    nInt := 0;
    FInit := GetTickCount;

    while True do
    begin
      nIV := GetTickCount - FInit;
      if nIV >= FDelay * 1000 then
      begin
        ShowMsg('������ʱ', '��ʾ');
        Result := '';
        Exit;
      end;

      if Trunc(nIV / 1000) <> nInt then
      begin
        nInt := Trunc(nIV / 1000);
        ShowWaitForm(nPForm, IntToStr(FDelay - nInt));
      end;

      Result := GetCardNO(nType);
      if not FConncted then
      begin
        ShowMsg('��������', '��ʾ');
        Exit;
      end;

      if Result <> '' then
      begin
        if nSendVK then
          SendKeyboard(nPForm.ActiveControl.Handle, Result);
        Exit;
      end;

      Sleep(250);
    end;
  finally
    CloseWaitForm;
  end;   
end;

//Date: 2014-06-11
//Parm: �ſ�����
//Desc: ��ȡnType�ĸ�ʽ������
function T900MReader.GetRegularFlag(const nType: Integer): Integer;
var nIdx: Integer;
begin
  Result := MaxInt;

  for nIdx:=Low(FFlags) to High(FFlags) do
  if FFlags[nIdx].FType = nType then
  begin
    Result := nIdx;
    break;
  end;
end;

function T900MReader.GetCardNO(const nType: Integer): string;
var nBuf: PChar;
    nInt,nPos: Integer;
    nStr,nTmp,nCard: string;
begin
  Result := '';
  try
    nInt := BC900_QueryListID(nBuf);
    if nInt <> 1 then Exit;

    //HC0F100008EE8F07D 1,HC0F00000000C8C83 3,NOTAG>
    nStr := StrPas(nBuf);
    nPos := Pos(',', nStr);

    while nPos > 1 do
    begin
      nCard := Copy(nStr, 1, nPos - 1);
      nInt := Pos(' ', nCard);

      if nInt > 1 then
      begin
        nTmp := Copy(nCard, 1, nInt - 1);
        System.Delete(nCard, 1, nInt);

        if IsNumber(nCard, False) and
           ((nType = -1) or (StrToInt(nCard) = nType)) then
        begin
          nInt := GetRegularFlag(nType);
          if nInt = MaxInt then
          begin
            Result := nTmp;
            Exit;
          end;

          with FFlags[nInt] do
          begin
            nPos := Length(nTmp) - FLength + 1;
            nTmp := Copy(nTmp, nPos, FLength);

            if Length(nTmp) = FLength then
              Result := nTmp;
            //xxxxx
          end;

          Exit;
        end;
      end;

      System.Delete(nStr, 1, nPos);
      nPos := Pos(',', nStr);
    end;
  except
    FConncted := False;
    CloseCommPort;
  end;
end;

//Date: 2014-06-09
//Parm: �ַ���
//Desc: ģ���������nStr����
procedure T900MReader.SendKeyboard(const nHandle: THandle; const nStr: string);
var nIdx,nLen,nKey: Integer;
begin
  nLen := Length(nStr);
  for nIdx:=1 to nLen do
  begin
    nKey := Ord(nStr[nIdx]);
    SendMessage(nHandle, WM_KEYDOWN, nKey, 0);
    SendMessage(nHandle, WM_CHAR, nKey, 0);
    SendMessage(nHandle, WM_KEYUP, nKey, 0);
  end;
end;

initialization
  g900MReader := nil;
finalization
  FreeAndNil(g900MReader);
end.
