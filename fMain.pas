unit fMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, dMain, ComCtrls, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdFTP, Buttons, ExtCtrls, IdIOHandler,
  IniFiles, IdExplicitTLSClientServerBase, IdFTPList, IDAllFTPListParsers;

type
  TfrmMain = class(TForm)
    edUser: TEdit;
    edPassword: TEdit;
    Host: TLabel;
    User: TLabel;
    Password: TLabel;
    btnConnect: TButton;
    lvFile: TListView;
    ftp: TIdFTP;
    Panel1: TPanel;
    btnDownload: TSpeedButton;
    btnUpload: TSpeedButton;
    btnDelFile: TSpeedButton;
    OpenDialog: TOpenDialog;
    Panel2: TPanel;
    btnMakeDir: TSpeedButton;
    btnDelDir: TSpeedButton;
    Status: TStatusBar;
    chkPassive: TCheckBox;
    labPath: TLabel;
    btnDisconnect: TButton;
    Label1: TLabel;
    edPort: TEdit;
    cbHost: TComboBox;
    tvDir: TTreeView;
    btnAbort: TSpeedButton;
    procedure btnConnectClick(Sender: TObject);
    procedure lvFileEdited(Sender: TObject; Item: TListItem;
      var S: String);
    procedure btnDownloadClick(Sender: TObject);
    procedure btnUploadClick(Sender: TObject);
    procedure btnDelFileClick(Sender: TObject);
    procedure btnDelDirClick(Sender: TObject);
    procedure btnMakeDirClick(Sender: TObject);
    procedure ftpStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: String);
    procedure ftpAfterClientLogin(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure cbHostSelect(Sender: TObject);
    procedure tvDirChange(Sender: TObject; Node: TTreeNode);
    procedure btnAbortClick(Sender: TObject);
    procedure ftpWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
  private
    FCurDir: string;
    Ini: TIniFile;
    WorkStart: cardinal;
    WorkSize: Int64;
    TotalSoFar: Int64;
    FTerminate: boolean;
    procedure Connect(const host, name, pwd: string);
    procedure DisplayTree(parent: TTreeNode = nil);
    procedure DisplayFolder;
    procedure UpdateIni;
    function GetDirPath(node: TTreeNode): string;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses FileCtrl;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ini := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  ini.ReadSection('Hosts', cbHost.Items);
  cbHost.ItemIndex := cbHost.Items.IndexOf(ini.ReadString('Current', 'Host', ''));
  cbHostSelect(cbHost);
end;

procedure TfrmMain.UpdateIni;
begin
  ini.WriteString('Hosts', cbHost.Text, '1');
  ini.WriteString(cbHost.Text, 'User', edUser.Text);
  ini.WriteString(cbHost.Text, 'Pass', edPassword.Text);
  ini.WriteBool(cbHost.Text, 'Passive', chkPassive.Checked);
  ini.WriteString(cbHost.Text, 'Port', edPort.Text);

  ini.WriteString('Current', 'Host', cbHost.Text);

  if cbHost.Items.IndexOf(cbHost.Text) < 0 then
    cbHost.Items.Add(cbHost.Text);
end;

procedure TfrmMain.cbHostSelect(Sender: TObject);
begin
  edUser.Text := ini.ReadString(cbHost.Text, 'User', '');
  edPassword.Text := ini.ReadString(cbHost.Text, 'Pass', '');
  chkPassive.Checked := ini.ReadBool(cbHost.Text, 'Passive', False);
  edPort.Text := ini.ReadString(cbHost.Text, 'Port', '21');
end;

procedure TfrmMain.btnConnectClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  try
    ftp.Passive := chkPassive.Checked;
    ftp.Port := StrToInt(Trim(edPort.Text));
    Connect(cbHost.Text, edUser.Text, edPassword.Text);
    UpdateIni;

    DisplayTree;

    DisplayFolder;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.Connect(const host, name, pwd: string);
begin
  Status.Panels[0].Text := 'Connecting'; Status.Refresh;
  ftp.Disconnect;
  ftp.Host := Trim(host);
  ftp.Username := Trim(name);
  ftp.Password := Trim(pwd);
  ftp.Connect();

  if not ftp.Connected then
    raise exception.Create('Unable to connect');
end;

procedure TfrmMain.btnDisconnectClick(Sender: TObject);
begin
  ftp.Disconnect;
end;

procedure TfrmMain.ftpStatus(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: String);
begin
  Status.Panels[0].Text := AStatusText;
  Status.Refresh;
end;

procedure TfrmMain.ftpAfterClientLogin(Sender: TObject);
begin
  Status.Panels[0].Text := 'Login successful'; Status.Refresh;
end;

procedure TfrmMain.DisplayTree(parent: TTreeNode = nil);
var i: integer;
    item: TTreeNode;
    dirs: TStringList;
begin
  tvDir.Items.BeginUpdate;
  dirs := TStringList.Create;

  if not Assigned(parent) then
  begin
    tvDir.Items.Clear;
    parent := tvDir.Items.Add(nil, ftp.RetrieveCurrentDir);
  end;

  ftp.List(nil);
  for i := 0 to ftp.DirectoryListing.Count - 1 do
  begin
    if ftp.DirectoryListing.Items[i].ItemType = ditDirectory then
    begin
      item := tvDir.Items.AddChild(parent, ftp.DirectoryListing.Items[i].FileName);
      dirs.AddObject(ftp.DirectoryListing.Items[i].FileName, item);
    end;
  end;
(*
  for i := 0 to dirs.Count - 1 do
  begin
    ftp.ChangeDir(dirs[i]);
    DisplayTree(TTreeNode(dirs.Objects[i]));
    ftp.ChangeDirUp;
  end;
*)
  tvDir.Items.EndUpdate;
  tvDir.Items[0].Expand(False);
end;

procedure TfrmMain.DisplayFolder;
var i: integer;
    item: TListItem;
begin
//  labPath.Caption := ftp.RetrieveCurrentDir;
  labPath.Caption := GetDirPath(tvDir.Selected);
  ftp.List(nil);
  lvFile.Clear;
  for i := 0 to ftp.DirectoryListing.Count - 1 do
  begin
    if ftp.DirectoryListing.Items[i].ItemType = ditFile then
    begin
      item := lvFile.Items.Add;
      item.Caption := ftp.DirectoryListing.Items[i].FileName;
      item.SubItems.Add(IntToStr(ftp.DirectoryListing.Items[i].Size));
      item.SubItems.Add(DateTimeToStr(ftp.DirectoryListing.Items[i].ModifiedDate));
      item.Data := ftp.DirectoryListing.Items[i]; // TidFTPListItem
    end;
  end;
end;

procedure TfrmMain.btnDownloadClick(Sender: TObject);
var i: integer;
  tick: cardinal;
  item: TidFTPListItem;
begin
  if SelectDirectory(FCurDir, [sdAllowCreate, sdPerformCreate], 0) then
  begin
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    btnAbort.Visible := True;
    try
      // calc total size
      WorkSize := 0;
      for i := 0 to lvFile.Items.Count - 1 do
      begin
        if lvFile.Items[i].Selected then
          WorkSize := WorkSize + TidFTPListItem(lvfile.Items[i].Data).Size;
      end;

      TotalSoFar := 0;
      WorkStart := GetTickCount;
      for i := 0 to lvFile.Items.Count - 1 do
      begin
        if lvFile.Items[i].Selected then
        begin
          Status.Panels[1].Text := 'Downloading ' + lvFile.Items[i].Caption; Status.Refresh;
          ftp.Get(lvFile.Items[i].Caption, FCurDir + '\' + lvFile.Items[i].Caption, True);
          TotalSoFar := TotalSoFar + TidFTPListItem(lvfile.Items[i].Data).Size;
        end;
      end;
    finally
      Screen.Cursor := crDefault;
      tick := GetTickCount - WorkStart;
      if tick > 0 then
      begin
        tick := WorkSize div tick;
        Status.Panels[1].Text := Format('%0.0dK  at %dK / second', [WorkSize div 1000, tick])
      end;

      btnAbort.Visible := False;
      WorkSize := 0;
    end;
    DisplayFolder;
  end;
end;

procedure TfrmMain.btnUploadClick(Sender: TObject);
var i: integer;
    sr: TSearchRec;
    ret: cardinal;
begin
  OpenDialog.Title := 'Files to upload ...';
  if OpenDialog.Execute then
  begin
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    btnAbort.Visible := True;
    try
      // calc total size
      WorkSize := 0;
      for i := 0 to OpenDialog.Files.Count - 1 do
      begin
        ret := FindFirst(OpenDialog.Files[i], faAnyFile, sr);
        if ret = 0 then
          WorkSize := WorkSize + sr.Size;
      end;

      TotalSoFar := 0;
      WorkStart := GetTickCount;
      for i := 0 to OpenDialog.Files.Count - 1 do
      begin
        Status.Panels[1].Text := 'Uploading ' + OpenDialog.Files[i]; Status.Refresh;
        ftp.Put(OpenDialog.Files[i], ExtractFileName(OpenDialog.Files[i]));
        ret := FindFirst(OpenDialog.Files[i], faAnyFile, sr);
        if ret = 0 then
          TotalSoFar := TotalSoFar + sr.Size;
      end;
    finally
      Screen.Cursor := crDefault;
      Status.Panels[1].Text := '';
      btnAbort.Visible := False;
      WorkSize := 0;
    end;
    DisplayFolder;
  end;
end;

procedure TfrmMain.lvFileEdited(Sender: TObject; Item: TListItem;
  var S: String);
begin
  ftp.Rename(item.Caption, S);
end;

procedure TfrmMain.btnDelFileClick(Sender: TObject);
var i: integer;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    for i := 0 to lvFile.Items.Count - 1 do
    begin
      if lvFile.Items[i].Selected then
      begin
        Status.Panels[1].Text := lvFile.Items[i].Caption; Status.Refresh;
        ftp.Delete(lvFile.Items[i].Caption);
      end;
    end;
  finally
    Screen.Cursor := crDefault;
    Status.Panels[1].Text := '';
  end;
  DisplayFolder;
end;

procedure TfrmMain.btnDelDirClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    if Assigned(tvDir.Selected) then
    begin
      ftp.ChangeDirUp;
      ftp.RemoveDir(GetDirPath(tvDir.Selected));
      DisplayFolder;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.btnMakeDirClick(Sender: TObject);
var dir: string;
begin
  if InputQuery('New Directory', 'Name', dir) then
  begin
    ftp.MakeDir(dir);
//    DisplayFolder;
    tvDir.Items.AddChild(tvDir.Selected, dir);
  end;
end;

function TfrmMain.GetDirPath(node: TTreeNode): string;
begin
  Result := '/';
  while Assigned(node) do
  begin
    if node.Text <> '/' then
      Result := '/' + node.Text + Result;
    node := node.Parent;
  end;
end;

procedure TfrmMain.tvDirChange(Sender: TObject; Node: TTreeNode);
begin
  ftp.ChangeDir(GetDirPath(Node));
  if not Node.HasChildren then
    DisplayTree(node);
  DisplayFolder;
end;

procedure TfrmMain.ftpWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
var s, s2: string;
    tick: Int64;
    sofar: int64;
begin
  if Worksize = 0 then
    Exit;

  sofar := TotalSoFar + AWorkCount;

  if AWorkMode = wmRead then s := 'Read: '
  else s := 'Written: ';

  s := s + Format('%0.0nK', [sofar / 1000]);

  tick := GetTickCount - WorkStart;
  if tick > 0 then
    tick := sofar div tick
  else
    tick := 0;
  if tick > 0 then
    sofar := Round((WorkSize - sofar) / tick / 1000)
  else
    sofar := 0;

  if sofar > 3600 then
    s2 := Format('%d:%.02d:%.02d', [sofar div 3600, (sofar mod 3600) div 60, sofar mod 60])
  else
    s2 := Format('%.02d:%.02d', [(sofar mod 3600) div 60, sofar mod 60]);

  s := s + Format(' (%dKBs) Time left: %s', [tick, s2]);
  Status.Panels[0].Text := s;

  Application.ProcessMessages;

  if FTerminate then
  begin
    FTerminate := False;
    ftp.Abort;
  end;
end;

procedure TfrmMain.btnAbortClick(Sender: TObject);
begin
  FTerminate := True;
end;

end.
