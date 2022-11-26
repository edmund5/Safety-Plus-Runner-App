program SafetyPlusRunner;

uses
  System.StartUpCopy,
  FMX.MobilePreview,
  FMX.Forms,
  MainUnit in 'MainUnit.pas' {Form1},
  Androidapi.JNI.Toast in 'Androidapi.JNI.Toast.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.FormFactor.Orientations := [TFormOrientation.Portrait];
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
