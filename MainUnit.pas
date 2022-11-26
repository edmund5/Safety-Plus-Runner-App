unit MainUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, System.Actions, System.Sensors, System.Sensors.Components,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.ActnList, FMX.Layouts, FMX.StdCtrls, FMX.Objects, FMX.Edit,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP,
  System.IniFiles, System.IOUtils, FMX.Media, FMX.Controls.Presentation;

type
  TForm1 = class(TForm)
    StyleBook1: TStyleBook;
    ActionList1: TActionList;
    LocationSensor1: TLocationSensor;
    MediaPlayer1: TMediaPlayer;
    Timer1: TTimer;
    Timer2: TTimer;
    Layout1: TLayout;
    Image1: TImage;
    TabControl1: TTabControl;
    NextTabAction1: TNextTabAction;
    PreviousTabAction1: TPreviousTabAction;
    TabItem1: TTabItem;
    BibNumber: TEdit;
    bgNEXT: TRectangle;
    lblNEXT: TLabel;
    NextTabAction2: TNextTabAction;
    PreviousTabAction2: TPreviousTabAction;
    TabItem2: TTabItem;
    ActivationCode: TEdit;
    bgACTIVATE: TRectangle;
    lblACTIVATE: TLabel;
    Loader: TRectangle;
    AniIndicator1: TAniIndicator;
    TabItem3: TTabItem;
    Layout2: TLayout;
    lblTime: TLabel;
    lblElapsedTime: TLabel;
    GridPanelLayout1: TGridPanelLayout;
    lblkm: TLabel;
    lblDistance: TLabel;
    lblkmh: TLabel;
    lblAvgSpeed: TLabel;
    Layout3: TLayout;
    bgSTARTSTOP: TRectangle;
    lblSTARTSTOP: TLabel;
    Layout4: TLayout;
    btnAction: TButton;
    NextTabAction3: TNextTabAction;
    PreviousTabAction3: TPreviousTabAction;
    TabItem4: TTabItem;
    Layout5: TLayout;
    bgSOS: TCircle;
    lblSOS: TLabel;
    lblInfo: TLabel;
    Layout6: TLayout;
    btnBack: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure lblNEXTClick(Sender: TObject);
    procedure lblACTIVATEClick(Sender: TObject);
    procedure lblSTARTSTOPClick(Sender: TObject);
    procedure LocationSensor1LocationChanged(Sender: TObject;
      const OldLocation, NewLocation: TLocationCoord2D);
    procedure BibNumberKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure ActivationCodeKeyUp(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
    procedure Timer1Timer(Sender: TObject);
    procedure btnActionClick(Sender: TObject);
    procedure lblSOSClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
  private
    { Private declarations }
    oLatitude: string;
    oLongitude: string;
    nLatitude: string;
    nLongitude: string;
    StartTime: TDateTime;
    ElapsedTime: TDateTime;
    TotalTime: TDateTime;
  public
    { Public declarations }
  end;

type
  TSubmitCoordinatesThread = class(TThread)
  private
    Time: Int64;
    Interval: Cardinal;
    IsBusy: Boolean;
    ServerResponse: string;
    Host: string;
    procedure UpdateVisual;
  protected
    procedure Execute; override;
  public
    constructor Create(Suspended: Boolean);
  end;

var
  Form1: TForm1;
  SubmitCoordinatesThread: TSubmitCoordinatesThread;

implementation

{$R *.fmx}

uses
  FMX.Helpers.Android,
  Androidapi.Helpers,
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNIBridge,
  Androidapi.JNI.Location,
  Androidapi.JNI.Telephony,
  FMX.FontGlyphs.Android,
  Androidapi.JNI.Toast,
  Math;

const
  // ---------------------------------------------------------------------------
  Host = 'the_backend_script_is_missing_sad_face';
  // ---------------------------------------------------------------------------

  ErrorLatLon = 'Unable to get your current GPS Coordinates.';

var
  E: extended;
  ConfigPath: string;

function HasPermission(const Permission: string): Boolean;
begin
  // Permissions listed at http://d.android.com/reference/android/Manifest.permission.html
  Result := SharedActivity.checkCallingOrSelfPermission
    (StringToJString(Permission)) = TJPackageManager.JavaClass.
    PERMISSION_GRANTED
end;

function MilesToKm(miles: double): double;
begin
  Result := miles * 1.609344;
end;

function DistanceBetweenLatLon(const Lat1, Lon1, Lat2, Lon2: extended)
  : extended;
begin
  Result := RadToDeg(Arccos(Sin(DegToRad(Lat1)) * Sin(DegToRad(Lat2)) +
    Cos(DegToRad(Lat1)) * Cos(DegToRad(Lat2)) * Cos(DegToRad(Lon1 - Lon2))
    )) * 69.09;
end;

function SpeedBetweenDistanceTime(kilometers: extended;
  ElapsedTime: string): double;
var
  HH, mm, ss, TimeSecs: integer;
  Distance, speed_mps, speed_kmh: double;
begin
  HH := StrToInt(Copy(ElapsedTime, 1, 2));
  mm := StrToInt(Copy(ElapsedTime, 4, 2));
  ss := StrToInt(Copy(ElapsedTime, 7, 2));
  Distance := kilometers * 1000;
  TimeSecs := HH * 3600 + mm * 60 + ss;
  speed_mps := Distance / TimeSecs; // meter
  speed_kmh := speed_mps * 3600 / 1000; // kilometer
  Result := speed_kmh;
end;

function ActivateTracker(aURL: string): string;
var
  lHTTP: TIdHTTP;
  lParamList: TStringList;
begin
  lHTTP := TIdHTTP.Create(nil);
  try
    lHTTP.Request.UserAgent :=
      'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:12.0) Gecko/20100101 Firefox/12.0';
    lParamList := TStringList.Create;
    try
      lParamList.Add('BibNumber=' + Form1.BibNumber.Text);
      lParamList.Add('ActivationCode=' + Form1.ActivationCode.Text);
      try
        Result := lHTTP.Post(aURL, lParamList);
      except
        on E: Exception do
          Result := IntToStr(lHTTP.ResponseCode);
      end;
    finally
      lParamList.Free;
    end;
  finally
    lHTTP.Free;
  end;
end;

procedure SendSMS(const Number, Msg: string);
var
  SmsManager: JSmsManager;
begin
  if not HasPermission('android.permission.SEND_SMS') then
    Toast('SOS does not have the send sms permission.')
  else
  begin
    SmsManager := TJSmsManager.JavaClass.getDefault;
    SmsManager.sendTextMessage(StringToJString(Number), nil,
      StringToJString(Msg), nil, nil);
  end;
end;

procedure TSubmitCoordinatesThread.UpdateVisual;
begin
  // ShowMessage(ServerResponse);
end;

constructor TSubmitCoordinatesThread.Create(Suspended: Boolean);
begin
  inherited Create(Suspended);
  Time := GetTickCount; // TimeGetTime;
end;

procedure TSubmitCoordinatesThread.Execute;
var
  lHTTP: TIdHTTP;
  lParamList: TStringList;
begin
  while not Terminated do
  begin
    Sleep(1);
    // TimeGetTime;
    if (GetTickCount - Time > Interval) and (not IsBusy) then
    begin
      IsBusy := True;
      lHTTP := TIdHTTP.Create(nil);
      try
        lHTTP.Request.UserAgent :=
          'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:12.0) Gecko/20100101 Firefox/12.0';
        lParamList := TStringList.Create;
        try
          lParamList.Add('BibNumber=' + Form1.BibNumber.Text);
          lParamList.Add('Latitude=' + Form1.nLatitude);
          lParamList.Add('Longitude=' + Form1.nLongitude);
          lParamList.Add('ElapsedTime=' + Form1.lblTime.Text);
          lParamList.Add('Distance=' + Form1.lblkm.Text);
          lParamList.Add('AvgSpeed=' + Form1.lblkmh.Text);
          try
            ServerResponse := lHTTP.Post(Host + 'update_tracker_data.php',
              lParamList);
          except
            on E: Exception do
              ServerResponse := IntToStr(lHTTP.ResponseCode);
          end;
        finally
          lParamList.Free;
        end;
      finally
        lHTTP.Free;
        IsBusy := False;
      end;
      Time := GetTickCount; // TimeGetTime;
      Synchronize(UpdateVisual);
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  ConfigInfo: TIniFile;
  TabIndex: string;
begin
  Sleep(1);
  LocationSensor1.Active := True; // Activate
  ConfigPath := TPath.Combine(TPath.GetHomePath, 'SafetyPlusRunner.dat');
  ConfigInfo := TIniFile.Create(ConfigPath);
  if FileExists(ConfigPath) then
  begin
    TabIndex := ConfigInfo.ReadString('SafetyPlusRunner', 'TabIndex', '');
    BibNumber.Text := ConfigInfo.ReadString('SafetyPlusRunner', 'BibNumber', '');
    if TabIndex = '0' then
    begin
      TabControl1.TabIndex := 0;
    end
    else if TabIndex = '2' then
    begin
      TabControl1.TabIndex := 2;
    end;
  end;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key = vkHardwareBack then
  begin
    // Handle
    Key := 0;
    if lblSTARTSTOP.Text = 'START' then
    begin
      // Previous
      if TabControl1.Index = 1 then
      begin
        PreviousTabAction1.ExecuteTarget(self);
      end
      else if TabControl1.Index = 2 then
      begin
        PreviousTabAction2.ExecuteTarget(self);
      end;
    end;
  end;
end;

procedure TForm1.lblNEXTClick(Sender: TObject);
begin
  NextTabAction1.ExecuteTarget(self);
end;

procedure TForm1.lblACTIVATEClick(Sender: TObject);
var
  ConfigInfo: TIniFile;
  ActivationStatus: string;
begin
  Loader.Visible := True;
  AniIndicator1.Enabled := True;
  Application.ProcessMessages;
  ConfigInfo := TIniFile.Create(ConfigPath);
  ActivationStatus := ActivateTracker(Host + 'activate_tracker.php');
  if ActivationStatus = 'VALID' then
  begin
    ConfigInfo.WriteString('SafetyPlusRunner', 'TabIndex', '2');
    ConfigInfo.WriteString('SafetyPlusRunner', 'BibNumber', BibNumber.Text);
    Loader.Visible := False;
    AniIndicator1.Enabled := False;
    Toast('Activation Successful.');
    NextTabAction2.ExecuteTarget(self);
  end
  else if ActivationStatus = 'INVALID' then
  begin
    ConfigInfo.WriteString('SafetyPlusRunner', 'TabIndex', '0');
    ConfigInfo.WriteString('SafetyPlusRunner', 'BibNumber', '');
    Loader.Visible := False;
    AniIndicator1.Enabled := False;
    Toast('Activation code is invalid.');
  end
  else
  begin
    Loader.Visible := True;
    AniIndicator1.Enabled := True;
    Toast('Activation needs internet.');
  end;
  FreeAndNil(ConfigInfo);
end;

procedure TForm1.lblSTARTSTOPClick(Sender: TObject);
var
  buttonSelected: integer;
  locationManager: JLocationManager;
  Intent: JIntent;
begin
  locationManager := TJLocationManager.Wrap
    (((SharedActivity.getSystemService(TJContext.JavaClass.LOCATION_SERVICE))
    as ILocalObject).GetObjectID);
  // ---------------------------------------------------------------------------
  if locationManager.isProviderEnabled(TJLocationManager.JavaClass.GPS_PROVIDER)
    = False then
  // locationManager.isProviderEnabled(TJLocationManager.JavaClass.NETWORK_PROVIDER) = False
  begin
    buttonSelected := MessageDlg('GPS is disabled! Do you want to enable it?',
      TMsgDlgType.mtCustom, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbCancel], 0);
    if buttonSelected = mrYes then
    begin
      Intent := TJIntent.JavaClass.init
        (StringToJString('android.settings.LOCATION_SOURCE_SETTINGS'));
      Intent.setPackage(StringToJString('com.android.settings'));
      // SharedActivity.startActivityForResult(Intent, 0);
      SharedActivity.startActivity(Intent);
      Exit;
    end
    else if buttonSelected = mrCancel then
    begin
      Exit;
    end;
  end;
  // ---------------------------------------------------------------------------
  if LocationSensor1.Active = True then
  begin
    LocationSensor1.Active := False;
    Sleep(1);
    LocationSensor1.Active := True; // Re-activate
  end
  else if LocationSensor1.Active = False then
  begin
    Sleep(1);
    LocationSensor1.Active := True; // Activate
  end;
  // ---------------------------------------------------------------------------
  if (length(Form1.oLatitude) = 0) or (length(Form1.oLongitude) = 0) then
  begin
    Toast(ErrorLatLon);
    Exit;
  end
  else if (Form1.oLatitude = 'NaN') or (Form1.oLongitude = 'NaN') then
  begin
    Toast(ErrorLatLon);
    Exit;
  end
  else if (LowerCase(Form1.oLatitude) = 'inf') or
    (LowerCase(Form1.oLongitude) = 'inf') then
  begin
    Toast(ErrorLatLon);
    Exit;
  end
  else if (LowerCase(Form1.oLatitude) = '-inf') or
    (LowerCase(Form1.oLongitude) = '-inf') then
  begin
    Toast(ErrorLatLon);
    Exit;
  end
  else if (LowerCase(Form1.oLatitude) = '+inf') or
    (LowerCase(Form1.oLongitude) = '+inf') then
  begin
    Toast(ErrorLatLon);
    Exit;
  end;
  // ---------------------------------------------------------------------------
  if lblSTARTSTOP.Text = 'START' then
  begin
    Timer1.Enabled := True;
    StartTime := Time;
    // Start the thread timer
    SubmitCoordinatesThread := TSubmitCoordinatesThread.Create(True);
    SubmitCoordinatesThread.FreeOnTerminate := True;
    SubmitCoordinatesThread.Interval := 1000; // 1 second
    SubmitCoordinatesThread.Host := Host; // Host here
    // Replace with resume in older version of delphi
    SubmitCoordinatesThread.Start;
    lblSTARTSTOP.Text := 'STOP';
  end
  else if lblSTARTSTOP.Text = 'STOP' then
  begin
    buttonSelected := MessageDlg('Are you sure you want to Stop?',
      TMsgDlgType.mtCustom, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0);
    if buttonSelected = mrYes then
    begin
      Timer1.Enabled := False;
      TotalTime := 0;
      // Stop the timer
      SubmitCoordinatesThread.Terminate;
      E := 0.00;
      lblTime.Text := '00:00:00';
      lblkm.Text := '0.00 km';
      lblkmh.Text := '0.0 km/h';
      Form1.oLatitude := '';
      Form1.oLongitude := '';
      Form1.nLatitude := '';
      Form1.nLongitude := '';
      // Pause
      // TotalTime := ElapsedTime;
      lblSTARTSTOP.Text := 'START';
    end;
  end;
end;

procedure TForm1.LocationSensor1LocationChanged(Sender: TObject;
  const OldLocation, NewLocation: TLocationCoord2D);
begin
  if lblSTARTSTOP.Text = 'START' then
  begin
    Form1.oLatitude := OldLocation.Latitude.ToString;
    Form1.oLongitude := OldLocation.Longitude.ToString;
  end
  else if lblSTARTSTOP.Text = 'STOP' then
  begin
    Form1.nLatitude := NewLocation.Latitude.ToString;
    Form1.nLongitude := NewLocation.Longitude.ToString;
  end;
end;

procedure TForm1.BibNumberKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    // Handle
    Key := 0;
    // Next
    lblNEXTClick(self);
    ActivationCode.SetFocus;
  end;
end;

procedure TForm1.ActivationCodeKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    // Handle
    Key := 0;
    // Next
    lblACTIVATEClick(self);
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  tempKM: string;
begin
  Application.ProcessMessages;
  ElapsedTime := Time - StartTime + TotalTime;
  lblTime.Text := FormatDateTime('hh:mm:ss', ElapsedTime);
  try
    // Calculate distance between latitude and longitude
    E := E + DistanceBetweenLatLon(StrToFloat(Form1.oLatitude),
      StrToFloat(Form1.oLongitude), StrToFloat(Form1.nLatitude),
      StrToFloat(Form1.nLongitude));
    lblkm.Text := FormatFloat('#,##0.00 km', MilesToKm(E));
    tempKM := FormatFloat('#,##0.00', MilesToKm(E));
    lblkmh.Text := FormatFloat('#,##0.0 km/h',
      SpeedBetweenDistanceTime(StrToFloat(tempKM), lblTime.Text));
    Form1.oLatitude := Form1.nLatitude;
    Form1.oLongitude := Form1.nLongitude;
  except
    // Unable to calculate distance between latitude and longitude
  end;
end;

procedure TForm1.btnActionClick(Sender: TObject);
begin
  NextTabAction3.ExecuteTarget(self);
end;

procedure TForm1.lblSOSClick(Sender: TObject);
var
  LocationInfo: string;
begin
  if lblSOS.Text = 'SOS' then
  begin
    lblSOS.Text := 'OFF';
    Timer2.Enabled := True;

    if (length(Form1.nLatitude) = 0) or (length(Form1.nLongitude) = 0) then
    begin
      LocationInfo := ' No Location Found.';
    end
    else if (Form1.nLatitude = 'NaN') or (Form1.nLongitude = 'NaN') then
    begin
      LocationInfo := ' No Location Found.';
    end
    else if (LowerCase(Form1.nLatitude) = 'inf') or
      (LowerCase(Form1.nLongitude) = 'inf') then
    begin
      LocationInfo := ' No Location Found.';
    end
    else if (LowerCase(Form1.nLatitude) = '-inf') or
      (LowerCase(Form1.nLongitude) = '-inf') then
    begin
      LocationInfo := ' No Location Found.';
    end
    else if (LowerCase(Form1.nLatitude) = '+inf') or
      (LowerCase(Form1.nLongitude) = '+inf') then
    begin
      LocationInfo := ' No Location Found.';
    end
    else
    begin
      LocationInfo := ' Current Location: https://maps.google.com/maps?q=' +
        Form1.nLatitude + ',' + Form1.nLongitude;
    end;

    // Send an SMS alert in case of emergency to
    SendSMS('replace_with_your_phone_number', 'Runner who wore Bib Number: ' + Form1.BibNumber.Text
      + ' is in need of help.' + LocationInfo);

  end
  else if lblSOS.Text = 'OFF' then
  begin
    lblSOS.Text := 'SOS';
    Timer2.Enabled := False;
  end;
end;

procedure TForm1.btnBackClick(Sender: TObject);
begin
  PreviousTabAction3.ExecuteTarget(self);
end;

procedure TForm1.Timer2Timer(Sender: TObject);
begin
  MediaPlayer1.FileName := TPath.Combine(TPath.GetHomePath, 'Alarm.mp3');
  MediaPlayer1.Volume := 100;
  MediaPlayer1.Play;
end;

end.
