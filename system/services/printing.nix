{
  config,
  pkgs,
  ...
}: let
  printer = "SCS-public";
in {
  services.printing.drivers = with pkgs; [foomatic-db-ppds];
  # print with lp
  hardware.printers = {
    ensureDefaultPrinter = printer;
    # https://computing.cs.cmu.edu/desktop/printing-linux-private
    ensurePrinters = [
      {
        name = printer;
        deviceUri = "lpd://jginesin@scs-print.srv.cs.cmu.edu/${printer}";
        model =
          pkgs.foomatic-db-ppds.pname
          + "/KONICA_MINOLTA-bizhub_360-Postscript-KONICA_MINOLTA.ppd.gz";
      }
    ];
  };
}
