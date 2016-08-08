unit dMain;

interface

uses
  SysUtils, Classes, IdBaseComponent, IdComponent, IdTCPConnection,
  IdTCPClient, IdFTP;

type
  TdmMain = class(TDataModule)
  private
    { Private declarations }
  public
  end;

var
  dmMain: TdmMain;

implementation

{$R *.dfm}

{ TdmMain }

end.
